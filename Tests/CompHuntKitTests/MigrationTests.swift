import Foundation
import SwiftData
import Testing
@testable import CompHuntKit

/// Guards the one failure that has no recovery path: a store written by an
/// already-installed version refusing to open after the schema changes. It
/// happens at launch, before there is any UI to report it in, and the person
/// sees a crash rather than a message.
///
/// The store must be file-backed. An in-memory store is created fresh every
/// time and so can never exercise a migration at all - it would pass whether
/// the plan worked or not.
@MainActor
@Suite struct MigrationTests {
    /// A fresh store path per test, torn down after.
    private func withTemporaryStore(
        _ body: (URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-migration-\(UUID().uuidString)",
                       directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "CompHunt.store"))
    }

    /// Writes rows through the frozen V1 shape, with no migration plan - the
    /// shape and the code path a shipped v0.1-v0.3 install used.
    private func seedV1Store(at url: URL, count: Int = 2) throws {
        let container = try ModelContainer(
            for: CompetitionSchemaV1.Competition.self,
            configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        for index in 0..<count {
            context.insert(CompetitionSchemaV1.Competition(
                key: "ctftime.org/event/\(index)",
                source: "ctftime",
                title: "Shipped competition \(index)"))
        }
        try context.save()
    }

    /// Writes rows through the frozen V2 shape - what every v1.0.x install
    /// has on disk.
    private func seedV2Store(at url: URL, count: Int = 2) throws {
        let container = try ModelContainer(
            for: CompetitionSchemaV2.Competition.self,
            configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        for index in 0..<count {
            let row = CompetitionSchemaV2.Competition(
                key: "ybox.vn/cuoc-thi/\(index)",
                source: "ybox",
                title: "Marked competition \(index)")
            row.statusRaw = "interested"
            context.insert(row)
        }
        try context.save()
    }

    private func openCurrentStore(at url: URL) throws -> ModelContext {
        let container = try ModelContainer(
            for: Competition.self,
            migrationPlan: CompetitionMigrationPlan.self,
            configurations: ModelConfiguration(url: url))
        return ModelContext(container)
    }

    @Test func aShippedStoreStillOpensAndKeepsItsRows() throws {
        try withTemporaryStore { url in
            try seedV1Store(at: url)

            let context = try openCurrentStore(at: url)
            let rows = try context.fetch(FetchDescriptor<Competition>())
                .sorted { $0.key < $1.key }

            #expect(rows.count == 2)
            #expect(rows.map(\.title) == ["Shipped competition 0",
                                          "Shipped competition 1"])
        }
    }

    /// The added column reads as "never marked" for rows that predate it,
    /// rather than as some default state the person did not choose.
    @Test func rowsFromBeforeTheColumnExistedReadAsUnmarked() throws {
        try withTemporaryStore { url in
            try seedV1Store(at: url)

            let context = try openCurrentStore(at: url)
            let rows = try context.fetch(FetchDescriptor<Competition>())

            #expect(rows.allSatisfy { $0.statusRaw == nil })
        }
    }

    /// Migrating is only half the job: the new column has to survive being
    /// written and the store being closed and reopened.
    @Test func aMarkWrittenAfterMigrationSurvivesAReopen() throws {
        try withTemporaryStore { url in
            try seedV1Store(at: url)

            let context = try openCurrentStore(at: url)
            let first = try #require(
                try context.fetch(FetchDescriptor<Competition>())
                    .sorted { $0.key < $1.key }.first)
            first.statusRaw = "applied"
            try context.save()

            let reopened = try openCurrentStore(at: url)
            let marked = try reopened.fetch(FetchDescriptor<Competition>())
                .filter { $0.statusRaw != nil }

            #expect(marked.count == 1)
            #expect(marked.first?.statusRaw == "applied")
        }
    }

    /// The plan has to be walkable in order, or a store two versions behind
    /// migrates through a stage that does not exist.
    @Test func everySchemaVersionHasAStageIntoTheNextOne() {
        #expect(CompetitionMigrationPlan.stages.count
            == CompetitionMigrationPlan.schemas.count - 1)
    }

    /// The population every current install is in: a V2 store, marks and all,
    /// crossing into V3. The mark must survive and the new column must read
    /// as "never computed" so the refresh backfill can find it.
    @Test func aV2StoreCrossesIntoV3KeepingItsMarks() throws {
        try withTemporaryStore { url in
            try seedV2Store(at: url)

            let context = try openCurrentStore(at: url)
            let rows = try context.fetch(FetchDescriptor<Competition>())

            #expect(rows.count == 2)
            #expect(rows.allSatisfy { $0.statusRaw == "interested" })
            #expect(rows.allSatisfy { $0.categoryTagsRaw.isEmpty })
        }
    }

    /// Tags written after migration survive a reopen, and the projection
    /// invariant holds through the round trip.
    @Test func tagsWrittenAfterMigrationSurviveAReopen() throws {
        try withTemporaryStore { url in
            try seedV1Store(at: url)

            let context = try openCurrentStore(at: url)
            let first = try #require(
                try context.fetch(FetchDescriptor<Competition>())
                    .sorted { $0.key < $1.key }.first)
            first.categoryTags = [.writing, .media]
            try context.save()

            let reopened = try openCurrentStore(at: url)
            let tagged = try #require(
                try reopened.fetch(FetchDescriptor<Competition>())
                    .first { !$0.categoryTagsRaw.isEmpty })

            #expect(tagged.categoryTags == [.writing, .media])
            #expect(tagged.category == .writing)
        }
    }
}
