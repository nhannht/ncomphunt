import Foundation
import SwiftData
import Testing
@testable import CompHuntKit

private struct ExplodingSource: CompetitionSource {
    let name = "exploding"
    func fetch() async throws -> [CompetitionDTO] {
        throw HTTPError.badStatus(code: 500, url: "https://example.com/boom")
    }
}

private struct SkippingSource: CompetitionSource {
    let name = "skipping"
    func fetch() async throws -> [CompetitionDTO] {
        throw SourceSkipped("no credentials")
    }
}

@MainActor
private func freshContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Competition.self, configurations: config)
    return ModelContext(container)
}

@MainActor
@Suite struct RefreshEngineBehavior {
    @Test func failingSourceNeverKillsTheRun() async throws {
        let context = try freshContext()
        let engine = RefreshEngine(sources: [ExplodingSource(), FakeSource(), SkippingSource()])
        let report = await engine.refresh(into: context)

        #expect(report.newCount == FakeSource.samples.count)
        let exploding = try #require(report.results.first { $0.source == "exploding" })
        guard case .failed = exploding.outcome else {
            Issue.record("expected .failed, got \(exploding.outcome)")
            return
        }
        let skipping = try #require(report.results.first { $0.source == "skipping" })
        #expect(skipping.outcome == .skipped("no credentials"))
        let fake = try #require(report.results.first { $0.source == "fake" })
        #expect(fake.outcome == .ok)
        #expect(fake.fetched == FakeSource.samples.count)
    }

    @Test func secondRefreshCreatesNoDuplicates() async throws {
        let context = try freshContext()
        let engine = RefreshEngine(sources: [FakeSource()])

        let first = await engine.refresh(into: context)
        #expect(first.newCount == FakeSource.samples.count)

        let second = await engine.refresh(into: context)
        #expect(second.newCount == 0)

        let all = try context.fetch(FetchDescriptor<Competition>())
        #expect(all.count == FakeSource.samples.count)
    }

    @Test func upsertPreservesFirstSeenAndTracking() async throws {
        let context = try freshContext()
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let late = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try CompetitionStore.upsert(FakeSource.samples, into: context, now: early)
        let key = FakeSource.samples[0].key
        let row = try #require(try context.fetch(
            FetchDescriptor<Competition>(predicate: #Predicate { $0.key == key })).first)
        row.trackedIssueID = "COMP-1"
        try context.save()

        var updated = FakeSource.samples[0]
        updated.prize = "$99,999"
        _ = try CompetitionStore.upsert([updated], into: context, now: late)

        let after = try #require(try context.fetch(
            FetchDescriptor<Competition>(predicate: #Predicate { $0.key == key })).first)
        #expect(after.firstSeen == early)
        #expect(after.lastSeen == late)
        #expect(after.prize == "$99,999")
        #expect(after.trackedIssueID == "COMP-1")
    }

    @Test func batchDedupeKeepsRichestSourceFirst() async throws {
        let context = try freshContext()
        let rich = CompetitionDTO(
            source: "ctftime", title: "Same Event", url: "https://example.com/e/1",
            category: .ctf, prize: "$5,000")
        let poor = CompetitionDTO(
            source: "clist", title: "Same Event", url: "https://example.com/e/1/")

        let newTitles = try CompetitionStore.upsert([rich, poor], into: context)
        #expect(newTitles.count == 1)

        let all = try context.fetch(FetchDescriptor<Competition>())
        #expect(all.count == 1)
        #expect(all[0].source == "ctftime")
        #expect(all[0].prize == "$5,000")
    }

    @Test func classificationIsAppliedOnInsert() async throws {
        let context = try freshContext()
        _ = try CompetitionStore.upsert(FakeSource.samples, into: context)
        let all = try context.fetch(FetchDescriptor<Competition>())

        let ctf = try #require(all.first { $0.title.contains("CTF") })
        #expect(ctf.category == .ctf)
        let vn = try #require(all.first { $0.title.contains("Lập Trình") })
        #expect(vn.region == .vietnam)
        #expect(vn.category == .cp)
        let ai = try #require(all.first { $0.title.contains("AI Grand") })
        #expect(ai.category == .ai)
    }
}
