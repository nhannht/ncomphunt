import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct CompetitionStatusTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func competition(title: String = "Sample Contest") -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, organizer: "", url: "https://example.com/\(title)",
            location: "", prize: "", startDate: nil, endDate: nil,
            registrationDeadline: nil)
        return Competition(dto: dto, category: .other, region: .global, now: now)
    }

    // MARK: the mark itself

    @Test func aFreshCompetitionIsUnmarked() {
        let row = competition()
        #expect(row.status == nil)
        #expect(!row.isMarked)
    }

    @Test func settingTheStatusMarksIt() {
        let row = competition()
        row.status = .applied
        #expect(row.statusRaw == "applied")
        #expect(row.isMarked)
    }

    @Test func clearingTheStatusUnmarksIt() {
        let row = competition()
        row.status = .joined
        row.status = nil
        #expect(row.statusRaw == nil)
        #expect(!row.isMarked)
    }

    /// A store written by a LATER build can carry a state this one has never
    /// heard of. Reading it as unmarked is survivable; trapping is not.
    @Test func anUnknownStoredStateReadsAsUnmarkedRatherThanTrapping() {
        let row = competition()
        row.statusRaw = "shortlisted-by-some-future-version"
        #expect(row.status == nil)
        #expect(!row.isMarked)
    }

    // MARK: which states still want telling about deadlines

    @Test func liveStatesWantRemindersAndFinishedOnesDoNot() {
        #expect(CompetitionStatus.interested.wantsReminders)
        #expect(CompetitionStatus.applied.wantsReminders)
        #expect(CompetitionStatus.joined.wantsReminders)
        #expect(!CompetitionStatus.done.wantsReminders)
        #expect(!CompetitionStatus.dropped.wantsReminders)
    }

    /// Dropping something is how you make it stop asking. If a dropped
    /// competition still reminded, the state would be useless.
    @Test func anUnmarkedCompetitionWantsNoReminders() {
        #expect(!competition().wantsReminders)
    }

    // MARK: the status: operator

    @Test func statusAnyMatchesEveryMarkedState() {
        let query = SearchQuery.parse("status:any")
        #expect(query.statuses == Set(CompetitionStatus.allCases))
        #expect(query.isMarkedOnly)
    }

    @Test func statusAnyAdmitsAnyMarkedRowAndRejectsUnmarkedOnes() {
        let query = SearchQuery.parse("status:any")
        let marked = competition(title: "Marked")
        marked.status = .dropped
        #expect(query.admits(marked, now: now))
        #expect(!query.admits(competition(title: "Unmarked"), now: now))
    }

    @Test func aSingleStateNarrowsToThatStateAlone() {
        let query = SearchQuery.parse("status:applied")
        let applied = competition(title: "Applied")
        applied.status = .applied
        let interested = competition(title: "Interested")
        interested.status = .interested
        #expect(query.admits(applied, now: now))
        #expect(!query.admits(interested, now: now))
    }

    /// Values are fuzzy the way `category:hackaton` already is, so the word a
    /// person reaches for first still works.
    @Test func commonSynonymsResolveToTheRightState() {
        #expect(SearchQuery.parse("status:starred").statuses == [.interested])
        #expect(SearchQuery.parse("status:submitted").statuses == [.applied])
        #expect(SearchQuery.parse("status:marked").statuses
            == Set(CompetitionStatus.allCases))
    }

    @Test func anEmptyQueryAdmitsUnmarkedCompetitions() {
        #expect(SearchQuery().admits(competition(), now: now))
        #expect(!SearchQuery().isMarkedOnly)
    }

    // MARK: round trip

    /// The Marked chip writes through `serialized()`, so all five states have to
    /// collapse back to the one short token rather than five.
    @Test func everyStateSerializesBackToStatusAny() {
        var query = SearchQuery()
        query.statuses = Set(CompetitionStatus.allCases)
        #expect(query.serialized() == "status:any")
        #expect(SearchQuery.parse(query.serialized()).statuses == query.statuses)
    }

    @Test func aSingleStateRoundTrips() {
        var query = SearchQuery()
        query.statuses = [.joined]
        #expect(query.serialized() == "status:joined")
        #expect(SearchQuery.parse(query.serialized()).statuses == [.joined])
    }

    // MARK: the dead-end diagnosis

    /// Filtering to marked with nothing marked is a dead end, and the empty
    /// state has to be able to name the filter that caused it.
    @Test func aMarkedFilterWithNothingMarkedIsDiagnosedAsTheCulprit() {
        let rows = [competition(title: "One"), competition(title: "Two")]
        let diagnosis = SearchQuery.parse("status:any")
            .narrowestConstraint(in: rows, now: now)
        #expect(diagnosis?.axis == .status)
        #expect(diagnosis?.countWithout == 2)
    }

    @Test func removingTheStatusAxisClearsEveryState() {
        var query = SearchQuery.parse("status:any")
        query.remove(.status)
        #expect(query.statuses.isEmpty)
        #expect(!query.isMarkedOnly)
    }
}
