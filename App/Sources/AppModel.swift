import CompHuntKit
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    let container: ModelContainer

    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?
    private(set) var lastReport: RefreshReport?
    private(set) var startupError: String?

    /// The next-contest snapshot the menu-bar countdown label renders.
    private(set) var menuBarStatus: MenuBarStatus?

    /// Staged by a `ncomphunt://open?key=` widget deep link; MainWindow consumes
    /// it to select the row.
    private(set) var deepLinkSelection: PersistentIdentifier?

    private var autoRefreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    /// The contest keys in the last snapshot written to the widget. Used to
    /// reload widget timelines only when the LIST changes, not every minute.
    private var lastSnapshotKeys: [String] = []

    init() {
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "CompHunt")
        do {
            try FileManager.default.createDirectory(
                at: supportDir, withIntermediateDirectories: true)
            let config = ModelConfiguration(url: supportDir.appending(path: "CompHunt.store"))
            container = try ModelContainer(for: Competition.self, configurations: config)
        } catch {
            // The store is a rebuildable cache: losing it costs one refresh.
            startupError = "Persistent store unavailable, using in-memory cache: \(error)"
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // A memory-only container cannot fail to open.
            container = try! ModelContainer(for: Competition.self, configurations: config)
        }
        startMenuBarCountdown()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // The very first refresh seeds the whole index; notifying about
        // a hundred "new" competitions then would be noise.
        let isInitialSeed = lastRefresh == nil
        // The source list is rebuilt every run so Settings toggles apply to
        // the very next refresh; search engines join at most once per day
        // to stay inside their free API quotas.
        let includeSearch = Self.searchWindowElapsed()
        let engine = RefreshEngine(sources: RefreshEngine.sources(
            enabled: SourcePreferences.enabled, includeSearch: includeSearch))
        let report = await engine.refresh(into: container.mainContext)
        lastReport = report
        lastRefresh = .now
        let searchRan = report.results.contains { result in
            SourceID(rawValue: result.source)?.isSearch == true && result.outcome == .ok
        }
        if searchRan {
            UserDefaults.standard.set(
                Date.now.timeIntervalSince1970, forKey: Self.lastSearchFetchKey)
        }
        if report.newCount > 0, !isInitialSeed {
            Notifier.postNewCompetitions(report.newTitles)
        }
        recomputeMenuBar()
    }

    private static let lastSearchFetchKey = "lastSearchFetch"

    private static func searchWindowElapsed(now: Date = .now) -> Bool {
        let last = UserDefaults.standard.double(forKey: lastSearchFetchKey)
        return now.timeIntervalSince1970 - last >= 24 * 3600
    }

}

/// Which sources the user ticked in Settings. Backed by UserDefaults so the
/// checkboxes and the refresh engine read the same truth; default is on.
enum SourcePreferences {
    static func enabledKey(_ id: SourceID) -> String {
        "source.\(id.rawValue).enabled"
    }

    static var enabled: Set<SourceID> {
        Set(SourceID.allCases.filter {
            UserDefaults.standard.object(forKey: enabledKey($0)) as? Bool ?? true
        })
    }
}

extension AppModel {
    /// Refresh now, then again every `interval`. Idempotent.
    func startAutoRefresh(interval: Duration = .seconds(3 * 3600)) {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }
}

/// The next-contest snapshot the menu-bar countdown label renders.
struct MenuBarStatus: Equatable {
    let code: String
    let countdown: String
    let url: String
    let title: String
}

extension AppModel {
    /// Recompute the menu-bar countdown from the current store and the persisted
    /// category + region filters, so the window and the menu bar agree.
    func recomputeMenuBar(now: Date = .now) {
        let all = (try? container.mainContext.fetch(FetchDescriptor<Competition>())) ?? []
        updateWidgetSnapshot(from: all, now: now)

        let category = CompetitionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.filter") ?? "all")?.categoryValue
        let region = RegionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.region") ?? "all")?.regionValue
        guard let next = nextUpcoming(in: all, category: category, region: region, now: now),
              let date = next.nextRelevantDate else {
            menuBarStatus = nil
            return
        }
        menuBarStatus = MenuBarStatus(
            code: next.category.shortCode,
            countdown: compactCountdown(to: date, now: now),
            url: next.url,
            title: next.title)
    }

    /// Write the next-contests snapshot for the widget every recompute (cheap
    /// atomic file write), but reload widget timelines only when the contest LIST
    /// changes - the countdown itself ticks via the widget's auto-updating Text,
    /// so a per-minute reload would waste the WidgetKit reload budget.
    private func updateWidgetSnapshot(from all: [Competition], now: Date) {
        let snapshot = widgetSnapshot(from: all, now: now)
        writeWidgetSnapshot(snapshot)
        let keys = snapshot.contests.map(\.key)
        if keys != lastSnapshotKeys {
            lastSnapshotKeys = keys
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Tick the countdown once a minute, aligned to the minute boundary so the
    /// displayed value never lags. Runs from launch, independent of any window.
    func startMenuBarCountdown() {
        guard countdownTask == nil else { return }
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.recomputeMenuBar()
                let seconds = Calendar.current.component(.second, from: .now)
                try? await Task.sleep(for: .seconds(60 - seconds))
            }
        }
    }
}

extension AppModel {
    /// Handle a `ncomphunt://open?key=<key>` deep link from the widget: find the
    /// competition, clear the list filters so its row is guaranteed visible, and
    /// stage it for MainWindow to select.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "ncomphunt", url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let key = components.queryItems?.first(where: { $0.name == "key" })?.value,
              !key.isEmpty
        else { return }
        let descriptor = FetchDescriptor<Competition>(predicate: #Predicate { $0.key == key })
        guard let match = try? container.mainContext.fetch(descriptor).first else { return }
        UserDefaults.standard.set(CompetitionFilter.all.rawValue, forKey: "list.filter")
        UserDefaults.standard.set(RegionFilter.all.rawValue, forKey: "list.region")
        deepLinkSelection = match.persistentModelID
    }

    func clearDeepLinkSelection() {
        deepLinkSelection = nil
    }
}
