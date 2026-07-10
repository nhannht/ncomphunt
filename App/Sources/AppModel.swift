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

    private let engine = RefreshEngine(sources: RefreshEngine.standardSources())
    private var autoRefreshTask: Task<Void, Never>?

    /// Fired after a refresh that found new competitions; the notifier hooks in here.
    var onNewCompetitions: (@MainActor ([String]) -> Void)?

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
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let report = await engine.refresh(into: container.mainContext)
        lastReport = report
        lastRefresh = .now
        if report.newCount > 0 {
            onNewCompetitions?(report.newTitles)
        }
    }

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
