import CompHuntKit
import CoreSpotlight
import EventKit
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    let container: ModelContainer

    private(set) var isRefreshing = false
    /// Mirrored into UserDefaults so "has this install ever refreshed" survives
    /// a relaunch. It gates the new-competition notification, and an in-memory
    /// value meant every launch's FIRST refresh was treated as the initial seed
    /// and silenced - which is the refresh most likely to have news.
    private(set) var lastRefresh: Date? {
        didSet {
            UserDefaults.standard.set(
                lastRefresh?.timeIntervalSince1970, forKey: Self.lastRefreshKey)
        }
    }
    private(set) var lastReport: RefreshReport?
    private(set) var startupError: String?

    /// The next-contest snapshot the menu-bar countdown label renders.
    private(set) var menuBarStatus: MenuBarStatus?

    /// Staged by a `ncomphunt://open?key=` widget deep link; MainWindow consumes
    /// it to select the row.
    private(set) var deepLinkSelection: PersistentIdentifier?

    /// Whether the dedicated nCompHunt calendar sync is on. Mirrors the service's
    /// UserDefaults flag as observable state so the Settings toggle re-renders
    /// (including flipping back if the user denies calendar access).
    private(set) var calendarSyncEnabled: Bool = CalendarSyncService.shared.isEnabled

    /// Notification state mirrored as observable properties, same reason as
    /// `calendarSyncEnabled`: the scheduler owns the truth, but a plain
    /// singleton read would never re-render the Settings rows.
    private(set) var remindersEnabled: Bool = ReminderScheduler.shared.isEnabled
    private(set) var scheduledReminderCount: Int = 0
    private(set) var digestEnabled: Bool = ReminderScheduler.shared.isDigestEnabled
    private(set) var digestTime: Date = ReminderScheduler.shared.digestTime

    private var autoRefreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    /// Held so the `.EKEventStoreChanged` observer lives as long as the model.
    private var calendarObserver: (any NSObjectProtocol)?

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
            // The migration plan is what lets a store written by v0.1-v0.3 open
            // at all after a property is added. Without it SwiftData traps.
            container = try ModelContainer(
                for: Competition.self, UserProfile.self,
                migrationPlan: CompetitionMigrationPlan.self,
                configurations: config)
        } catch {
            // The store is a rebuildable cache: losing it costs one refresh.
            startupError = "Persistent store unavailable, using in-memory cache: \(error)"
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // A memory-only container cannot fail to open.
            container = try! ModelContainer(
                for: Competition.self, UserProfile.self, configurations: config)
        }
        // Adopt the persisted value at launch so the "last refreshed" labels
        // report the install's history, not "never" on every start.
        let stored = UserDefaults.standard.double(forKey: Self.lastRefreshKey)
        if stored > 0 { lastRefresh = Date(timeIntervalSince1970: stored) }
        // Busy windows BEFORE the countdown starts, so the first menu-bar
        // recompute already ranks against the real calendar.
        refreshBusyIntervals()
        watchCalendarChanges()
        startMenuBarCountdown()
    }

    private static let lastRefreshKey = "lastRefresh"

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
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
        // Nothing is posted here any more. A refresh runs every three hours and
        // interrupting on each one that found something was the app talking
        // about competitions nobody had asked about. What arrived is reported
        // once, in the morning digest, off `firstSeen`.
        refreshBusyIntervals()
        recomputeMenuBar()
        let all = allCompetitions()
        await CalendarSyncService.shared.syncIfEnabled(competitions: all)
        await ReminderScheduler.shared.reschedule(competitions: all)
        #if os(iOS)
        await ContestActivities.reconcile(competitions: all)
        #endif
        await donateToSpotlight(all)
        adoptReminderState()
        await refreshCodeforcesRating()
    }

    /// Refreshes the profile's cached Codeforces rating on the same cycle as
    /// the sources, at most once a day - never on read (COMP-17). Failure is
    /// silently non-fatal: the cached rating stays, the FitScorer rating
    /// component degrades to neutral, and no refresh is ever killed by it.
    private func refreshCodeforcesRating(now: Date = .now) async {
        guard let profile = try? container.mainContext
            .fetch(FetchDescriptor<UserProfile>()).first else { return }
        let handle = profile.cfHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { return }
        if let updated = profile.cfRatingUpdated,
           now.timeIntervalSince(updated) < 24 * 3600 { return }
        guard let rating = try? await CodeforcesRating.fetch(handle: handle)
        else { return }
        profile.cfRating = rating
        profile.cfRatingUpdated = now
        try? container.mainContext.save()
    }

    /// Every persisted competition, or an empty array if the store read fails.
    /// Internal rather than private: the App Intents query layer reads the
    /// store through this one model (registered as a dependency), never
    /// through a second container on the same file.
    func allCompetitions() -> [Competition] {
        (try? container.mainContext.fetch(FetchDescriptor<Competition>())) ?? []
    }

    /// The row for a dedupe key: the one lookup behind the deep link route
    /// and entity resolution.
    func competition(forKey key: String) -> Competition? {
        let descriptor = FetchDescriptor<Competition>(
            predicate: #Predicate { $0.key == key })
        return try? container.mainContext.fetch(descriptor).first
    }

    /// Spotlight mirrors the store: the whole set is re-donated after every
    /// refresh - the same self-healing re-derivation the reminders use - so a
    /// pruned row falls out of Spotlight by construction. Failure is non-fatal
    /// and never kills a refresh.
    private func donateToSpotlight(_ competitions: [Competition]) async {
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAllSearchableItems()
            try await index.indexAppEntities(competitions.map(CompetitionEntity.init))
        } catch {
            FileHandle.standardError.write(
                Data("[comphunt] spotlight donation failed: \(error)\n".utf8))
        }
    }

    #if os(iOS)
    /// Foreground reconcile for the Live Activity: a face flip (registration
    /// -> pre-start -> running) that happened while the app was backgrounded
    /// is applied the moment the app is looked at, not only on the next
    /// refresh cycle.
    func reconcileActivities() async {
        await ContestActivities.reconcile(competitions: allCompetitions())
    }
    #endif

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
    /// category + region filters, so the window and the menu bar agree. The
    /// countdown target is the BEST-FIT upcoming competition (COMP-19), not
    /// merely the soonest - the surface seen every day is where the ranking
    /// earns its keep.
    func recomputeMenuBar(now: Date = .now) {
        let all = (try? container.mainContext.fetch(FetchDescriptor<Competition>())) ?? []
        // The model adopts the profile itself: this runs from launch, every
        // minute, before any window body has ever evaluated - it cannot wait
        // for the list pane's adoption pass.
        FitContext.adopt(
            (try? container.mainContext.fetch(FetchDescriptor<UserProfile>()))?
                .first?.snapshot() ?? .defaults)
        updateWidgetSnapshot(from: all, now: now)

        let category = CompetitionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.filter") ?? "all")?.categoryValue
        let region = RegionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.region") ?? "all")?.regionValue
        guard let pick = FitScorer.topPick(
            in: all, category: category, region: region,
            profile: FitContext.current, busy: FitContext.currentBusy, now: now),
            let date = pick.competition.nextRelevantDate else {
            menuBarStatus = nil
            return
        }
        menuBarStatus = MenuBarStatus(
            code: pick.competition.category.shortCode,
            countdown: compactCountdown(to: date, now: now),
            url: pick.competition.url,
            title: pick.competition.title)
    }

    /// Write the next-contests snapshot for the widget every recompute (cheap
    /// atomic file write), but reload widget timelines only when the contest LIST
    /// changes - the countdown itself ticks via the widget's auto-updating Text,
    /// so a per-minute reload would waste the WidgetKit reload budget.
    private func updateWidgetSnapshot(from all: [Competition], now: Date) {
        let snapshot = widgetSnapshot(
            from: all, profile: FitContext.current,
            busy: FitContext.currentBusy, now: now)
        writeWidgetSnapshot(snapshot)
        // The pick's key and score join the change detection so a re-ranked
        // featured row reloads too; its REASON text does not, because a
        // countdown-bearing reason changes every minute and the hourly
        // timeline policy already caps that staleness.
        var keys = snapshot.contests.map(\.key)
        if let pick = snapshot.topPick {
            keys.append("pick:\(pick.contest.key):\(pick.score)")
        }
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
        guard let match = competition(forKey: key) else { return }
        // The window filters on `list.query`; `list.filter` and `list.region`
        // are DERIVED from it for the menu bar and the widget. Clearing only the
        // derived pair left an active query in force, so a deep link to a
        // competition outside it selected a row that was not on screen.
        // Clearing the query is what "make its row visible" now means, and
        // `syncMenuBarLens` re-derives the other two from it.
        UserDefaults.standard.set("", forKey: "list.query")
        UserDefaults.standard.set(CompetitionFilter.all.rawValue, forKey: "list.filter")
        UserDefaults.standard.set(RegionFilter.all.rawValue, forKey: "list.region")
        deepLinkSelection = match.persistentModelID
    }

    func clearDeepLinkSelection() {
        deepLinkSelection = nil
    }
}

extension AppModel {
    /// One-line status for the Settings calendar row.
    var calendarStatusText: String { CalendarSyncService.shared.statusText }

    /// Toggle the dedicated-calendar sync. Turning it on requests full calendar
    /// access and, on grant, runs an immediate reconcile; a denial flips the
    /// observable flag back off so the checkbox reflects reality.
    func setCalendarSync(_ on: Bool) {
        if on {
            Task {
                calendarSyncEnabled = await CalendarSyncService.shared.enable(
                    with: allCompetitions())
                // Enabling is the moment access may have just been granted,
                // so the first busy read that can succeed happens now.
                refreshBusyIntervals()
                recomputeMenuBar()
            }
        } else {
            CalendarSyncService.shared.disable()
            calendarSyncEnabled = false
        }
    }

    /// Read the calendar's busy windows over the scoring horizon and adopt
    /// them into `FitContext`, so every fit score sees real conflicts
    /// (COMP-18). Safe to call anytime: without calendar access the read is
    /// empty, which scores identically to a free calendar - degradation is
    /// silence, never an error surface.
    func refreshBusyIntervals(now: Date = .now) {
        FitContext.adoptBusy(CalendarSyncService.shared.busyIntervals(
            from: now, to: now.addingTimeInterval(90 * 86_400)))
    }

    /// Re-rank when the system calendar database changes, so an event added
    /// in Calendar.app moves fit scores without waiting for a refresh. Our
    /// own sync writes fire this too - harmless, because the busy read
    /// excludes the nCompHunt calendar.
    private func watchCalendarChanges() {
        guard calendarObserver == nil else { return }
        calendarObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBusyIntervals()
                self?.recomputeMenuBar()
            }
        }
    }

    /// Explicit teardown: stop syncing and delete the calendar and its events.
    func removeCalendar() {
        CalendarSyncService.shared.disable()
        CalendarSyncService.shared.removeCalendar()
        calendarSyncEnabled = false
    }
}

extension AppModel {
    /// Mark, re-mark, or unmark one competition.
    ///
    /// The single write path for the app's only user-authored state. Views call
    /// this rather than assigning through their own model context, so the save
    /// and the reminder reschedule that follows a mark cannot come apart.
    func setStatus(_ status: CompetitionStatus?, for competition: Competition) {
        guard competition.status != status else { return }
        competition.status = status
        do {
            try container.mainContext.save()
        } catch {
            // Posted, not written to `startupError` - nothing reads that, so a
            // failure assigned there is exactly as silent as no report at all.
            // A mark is the only thing in the store the person put in by hand,
            // so losing one has to be visible. Same route the YouTrack filing
            // outcomes take, for the same reason: the menu is already gone.
            Notifier.post("Could not save your mark",
                          body: error.localizedDescription)
            return
        }
        // Immediately, not at the next refresh. Marking something is a request
        // to be told about it, and a reminder that only starts existing three
        // hours later can miss the deadline it was asked to cover.
        Task {
            await ReminderScheduler.shared.reschedule(competitions: allCompetitions())
            adoptReminderState()
        }
    }

    func setRemindersEnabled(_ on: Bool) {
        Task {
            await ReminderScheduler.shared.setEnabled(on, competitions: allCompetitions())
            adoptReminderState()
        }
    }

    func setDigestEnabled(_ on: Bool) {
        Task {
            await ReminderScheduler.shared.setDigestEnabled(
                on, competitions: allCompetitions())
            adoptReminderState()
        }
    }

    func setDigestTime(_ time: Date) {
        Task {
            await ReminderScheduler.shared.setDigestTime(
                time, competitions: allCompetitions())
            adoptReminderState()
        }
    }

    /// Read the true pending count back on launch, before any refresh has run.
    func loadReminderStatus() {
        Task {
            await ReminderScheduler.shared.refreshScheduledCount()
            adoptReminderState()
        }
    }

    /// Pull the scheduler's truth into the observable mirrors.
    func adoptReminderState() {
        remindersEnabled = ReminderScheduler.shared.isEnabled
        scheduledReminderCount = ReminderScheduler.shared.scheduledCount
        digestEnabled = ReminderScheduler.shared.isDigestEnabled
        digestTime = ReminderScheduler.shared.digestTime
    }
}
