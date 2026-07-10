import Foundation
import SwiftData
import Testing
@testable import CompHuntKit

@Suite struct DTOFillMissing {
    @Test func fillsOnlyEmptyFields() {
        var kept = CompetitionDTO(
            source: "ctftime", title: "Event", url: "https://example.com/e",
            prize: "$5,000")
        let duplicate = CompetitionDTO(
            source: "clist", title: "Event", organizer: "Org", url: "https://example.com/e/",
            prize: "$1", startDate: Date(timeIntervalSince1970: 1_900_000_000),
            tags: ["clist"])

        kept.fillMissing(from: duplicate)
        #expect(kept.prize == "$5,000")
        #expect(kept.organizer == "Org")
        #expect(kept.startDate == Date(timeIntervalSince1970: 1_900_000_000))
        #expect(kept.tags.contains("clist"))
        #expect(kept.source == "ctftime")
    }
}

@MainActor
@Suite struct NeverDowngradeUpdate {
    private func context() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Competition.self, configurations: config))
    }

    @Test func slimCopyCannotEraseKnownFields() throws {
        let context = try context()
        let deadline = Date(timeIntervalSince1970: 1_900_000_000)
        let rich = CompetitionDTO(
            source: "ybox", title: "[Online] Cuộc Thi X", url: "https://ybox.vn/cuoc-thi/x",
            location: "Hồ Chí Minh", prize: "50.000.000 VNĐ", details: "Chi tiết",
            registrationDeadline: deadline)
        _ = try CompetitionStore.upsert([rich], into: context)

        let slim = CompetitionDTO(
            source: "ybox", title: "[Online] Cuộc Thi X", url: "https://ybox.vn/cuoc-thi/x")
        _ = try CompetitionStore.upsert([slim], into: context)

        let row = try #require(try context.fetch(FetchDescriptor<Competition>()).first)
        #expect(row.registrationDeadline == deadline)
        #expect(row.prize == "50.000.000 VNĐ")
        #expect(row.location == "Hồ Chí Minh")
        #expect(row.details == "Chi tiết")
        #expect(row.region == .vietnam)
    }

    @Test func categoryNeverFallsBackToOther() throws {
        let context = try context()
        let typed = CompetitionDTO(
            source: "fake", title: "Some Event", url: "https://example.com/e", category: .ctf)
        _ = try CompetitionStore.upsert([typed], into: context)

        let untyped = CompetitionDTO(
            source: "fake", title: "Some Event", url: "https://example.com/e")
        _ = try CompetitionStore.upsert([untyped], into: context)

        let row = try #require(try context.fetch(FetchDescriptor<Competition>()).first)
        #expect(row.category == .ctf)
    }

    @Test func genuineUpdatesStillApply() throws {
        let context = try context()
        let original = CompetitionDTO(
            source: "fake", title: "Event", url: "https://example.com/e",
            prize: "$100",
            registrationDeadline: Date(timeIntervalSince1970: 1_900_000_000))
        _ = try CompetitionStore.upsert([original], into: context)

        let extendedDeadline = Date(timeIntervalSince1970: 1_950_000_000)
        let updated = CompetitionDTO(
            source: "fake", title: "Event", url: "https://example.com/e",
            prize: "$500", registrationDeadline: extendedDeadline)
        _ = try CompetitionStore.upsert([updated], into: context)

        let row = try #require(try context.fetch(FetchDescriptor<Competition>()).first)
        #expect(row.prize == "$500")
        #expect(row.registrationDeadline == extendedDeadline)
    }
}
