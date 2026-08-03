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

    /// A feed only lists what is current, so a row that scrolled off is never
    /// handed to the classifier again and keeps the answer it got the day it
    /// was last served. On a live store 73 of 117 ybox rows were in that state,
    /// carrying answers from a build with four fewer categories in it.
    @Test func aRowNoSourceStillServesIsStillReclassified() throws {
        let context = try freshContext()
        let stranded = Competition(
            dto: CompetitionDTO(
                source: "ybox",
                title: "[HN] Cuộc Thi Hùng Biện Kinh Tế Đỉnh Cao",
                url: "https://ybox.vn/cuoc-thi/stranded"),
            tags: [], region: .vietnam)
        context.insert(stranded)
        try context.save()

        #expect(try CompetitionStore.reclassifyUnplaced(context) == 1)
        #expect(stranded.category == .academic)
    }

    /// The pass may only ever improve a row. A category already on a row can
    /// have come from a source that DECLARED it, and the store does not record
    /// which answers were declared - so re-deriving one from stored text would
    /// downgrade it. `.other` is the only value with nothing below it.
    @Test func aRowThatAlreadyLandedIsNeverTouched() throws {
        let context = try freshContext()
        // What MLContests declares: nothing in the title says "ai".
        let declared = Competition(
            dto: CompetitionDTO(
                source: "mlcontests", title: "NextGen Innovation 2026",
                url: "https://example.com/nextgen"),
            tags: [.ai], region: .global)
        context.insert(declared)
        try context.save()

        #expect(try CompetitionStore.reclassifyUnplaced(context) == 0)
        #expect(declared.category == .ai)
    }

    /// An honest `.other` survives the pass. Most ybox titles name the prize
    /// and never the activity, so there is nothing in them to match.
    @Test func aRowWithNothingToMatchStaysOther() throws {
        let context = try freshContext()
        let unplaceable = Competition(
            dto: CompetitionDTO(
                source: "ybox",
                title: "[Toàn Cầu] Cơ Hội Nhận 1 Tỷ Đồng Từ Chương Trình Connections",
                url: "https://ybox.vn/cuoc-thi/unplaceable"),
            tags: [], region: .vietnam)
        context.insert(unplaceable)
        try context.save()

        #expect(try CompetitionStore.reclassifyUnplaced(context) == 0)
        #expect(unplaceable.category == .other)
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

@MainActor
@Suite struct PersistedTags {
    /// Upsert stores the classifier's whole answer, and the single category is
    /// its first entry - a projection, never a second decision.
    @Test func upsertPersistsEveryTagAndTheProjection() throws {
        let context = try freshContext()
        let multi = CompetitionDTO(
            source: "ybox",
            title: "Cuộc Thi Sáng Tác Thơ, Âm Nhạc, Nhiếp Ảnh",
            url: "https://ybox.vn/cuoc-thi/tho-nhac-anh")
        _ = try CompetitionStore.upsert([multi], into: context)

        let row = try #require(try context.fetch(FetchDescriptor<Competition>()).first)
        #expect(row.categoryTags == [.writing, .media])
        #expect(row.category == .writing)
        #expect(row.belongs(to: .media))
    }

    /// The rescue pass writes the whole tag set too, not just a category.
    @Test func rescueWritesTags() throws {
        let context = try freshContext()
        let stranded = Competition(
            dto: CompetitionDTO(
                source: "ybox",
                title: "Cuộc Thi Sáng Tác Thơ Và Nhiếp Ảnh",
                url: "https://ybox.vn/cuoc-thi/stranded-tags"),
            tags: [], region: .vietnam)
        context.insert(stranded)
        try context.save()

        #expect(try CompetitionStore.reclassifyUnplaced(context) == 1)
        #expect(stranded.categoryTags == [.writing, .media])
        #expect(stranded.category == .writing)
    }

    /// Backfill for rows that predate the tags column. The stored category may
    /// have been DECLARED by a source and nothing in the text says it, so it
    /// stays first - no row can downgrade - and what the text does say is
    /// appended after it.
    @Test func backfillKeepsTheStoredCategoryFirst() throws {
        let context = try freshContext()
        // What MLContests declares .ai about; the title itself reads as media.
        let declared = Competition(
            dto: CompetitionDTO(
                source: "mlcontests", title: "Video Understanding Challenge",
                url: "https://example.com/video-ai"),
            tags: [.ai], region: .global)
        context.insert(declared)
        try context.save()
        // Simulate a row migrated from before the column existed.
        declared.categoryTagsRaw = ""

        #expect(try CompetitionStore.backfillMissingTags(context) == 1)
        #expect(declared.categoryTags == [.ai, .media])
        #expect(declared.category == .ai)

        // One-time by construction: the set it fills can never match again.
        #expect(try CompetitionStore.backfillMissingTags(context) == 0)
    }

    /// `.other` rows are not backfill's to touch - they belong to the rescue
    /// pass, which may still move them somewhere real.
    @Test func backfillLeavesOtherRowsToTheRescuePass() throws {
        let context = try freshContext()
        let unplaced = Competition(
            dto: CompetitionDTO(
                source: "ybox", title: "Chương Trình Trao Đổi Văn Hóa",
                url: "https://ybox.vn/cuoc-thi/vanhoa"),
            tags: [], region: .vietnam)
        context.insert(unplaced)
        try context.save()

        #expect(try CompetitionStore.backfillMissingTags(context) == 0)
        #expect(unplaced.categoryTagsRaw.isEmpty)
    }
}
