import Foundation
import SwiftData
import Testing
@testable import CompHuntKit

@Suite struct SourceRegistry {
    @Test func rawValuesMatchSourceNames() {
        for id in SourceID.allCases {
            #expect(id.makeSource().name == id.rawValue)
        }
    }

    @Test func standardSourcesCoverTheWholeRegistry() {
        let names = RefreshEngine.standardSources().map(\.name)
        #expect(names == SourceID.allCases.map(\.rawValue))
    }

    @Test func enabledFilterRespectsSelectionAndOrder() {
        let sources = RefreshEngine.sources(
            enabled: [.ybox, .ctftime, .brave], includeSearch: true)
        // Registry order, not selection order.
        #expect(sources.map(\.name) == ["ctftime", "ybox", "brave"])
    }

    @Test func searchGateExcludesMeteredSources() {
        let sources = RefreshEngine.sources(
            enabled: Set(SourceID.allCases), includeSearch: false)
        #expect(!sources.contains { $0.name == "brave" || $0.name == "googlesearch" })
        #expect(sources.contains { $0.name == "ctftime" })
    }

    @Test func onlySearchSourcesAreMetered() {
        #expect(SourceID.allCases.filter(\.isSearch) == [.brave, .googlesearch])
    }
}

@MainActor
@Suite struct StorePruning {
    private func context() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Competition.self, configurations: config))
    }

    private func insert(
        _ context: ModelContext, title: String, lastSeen: Date,
        deadline: Date? = nil, tracked: String? = nil
    ) {
        let dto = CompetitionDTO(
            source: "brave", title: title,
            url: "https://example.com/\(title.hashValue.magnitude)",
            registrationDeadline: deadline)
        let row = Competition(dto: dto, category: .other, region: .global, now: lastSeen)
        row.trackedIssueID = tracked
        context.insert(row)
    }

    @Test func removesOnlyStaleUntrackedDatelessRows() throws {
        let context = try context()
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let old = now.addingTimeInterval(-20 * 24 * 3600)
        let fresh = now.addingTimeInterval(-2 * 24 * 3600)

        insert(context, title: "stale lead", lastSeen: old)
        insert(context, title: "fresh lead", lastSeen: fresh)
        insert(context, title: "stale but dated", lastSeen: old,
               deadline: now.addingTimeInterval(30 * 24 * 3600))
        insert(context, title: "stale but tracked", lastSeen: old, tracked: "COMP-9")
        try context.save()

        let removed = try CompetitionStore.prune(context, now: now)
        #expect(removed == 1)

        let remaining = try context.fetch(FetchDescriptor<Competition>()).map(\.title)
        #expect(!remaining.contains("stale lead"))
        #expect(remaining.count == 3)
    }
}
