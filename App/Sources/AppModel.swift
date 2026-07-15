import CompHuntKit
import Foundation
import SwiftData
import SwiftUI

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

    private var autoRefreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

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
