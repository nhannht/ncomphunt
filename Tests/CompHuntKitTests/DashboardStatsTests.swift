import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct DashboardStatsTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func ahead(_ hours: Double) -> Date {
        now.addingTimeInterval(hours * 3600)
    }

    private func competition(
        title: String = "Contest",
        source: String = "ctftime",
        category: CompetitionCategory = .ctf,
        region: Region = .global,
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil,
        status: CompetitionStatus? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: source, title: title, organizer: "",
            url: "https://example.com/\(title)", location: "", prize: "",
            startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        let row = Competition(dto: dto, tags: category == .other ? [] : [category], region: region, now: now)
        row.status = status
        return row
    }

    // MARK: the pipeline

    /// Every state is present even at zero. A funnel with holes punched in it
    /// cannot be read as a funnel.
    @Test func theFunnelAlwaysCarriesEveryStateInPipelineOrder() {
        let stats = DashboardStats(for: [competition(status: .applied)], now: now)
        #expect(stats.byStatus.map(\.key) == CompetitionStatus.allCases)
        #expect(stats.byStatus.first { $0.key == .applied }?.count == 1)
        #expect(stats.byStatus.first { $0.key == .joined }?.count == 0)
    }

    @Test func countsMarkedAndUnmarkedSeparately() {
        let rows = [
            competition(title: "A", status: .interested),
            competition(title: "B", status: .done),
            competition(title: "C", status: nil),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.total == 3)
        #expect(stats.marked == 2)
    }

    /// This is what the reminder schedule is derived from, so the dashboard has
    /// to count it the same way: marked, still live, and still has a date.
    @Test func markedWithDeadlineMatchesWhatWouldBeScheduled() {
        let rows = [
            competition(title: "Live", registrationDeadline: ahead(72), status: .applied),
            competition(title: "Finished", registrationDeadline: ahead(72), status: .done),
            competition(title: "Dateless", status: .interested),
            competition(title: "Unmarked", registrationDeadline: ahead(72)),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.markedWithDeadline == 1)
        let scheduled = Set(ReminderPlan.plans(for: rows, now: now).map(\.key))
        #expect(scheduled.count == stats.markedWithDeadline)
    }

    // MARK: the shape

    @Test func countsWhatIsRunningRightNow() {
        let rows = [
            competition(title: "Running", startDate: ahead(-24), endDate: ahead(24)),
            competition(title: "Upcoming", startDate: ahead(24), endDate: ahead(48)),
            competition(title: "Over", startDate: ahead(-48), endDate: ahead(-24)),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.runningNow == 1)
        #expect(stats.ended == 1)
    }

    @Test func countsWhatClosesInsideTheHorizon() {
        let rows = [
            competition(title: "Soon", registrationDeadline: ahead(48)),
            competition(title: "Later", registrationDeadline: ahead(24 * 30)),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.closingThisWeek == 1)
    }

    /// A dateless lead is not a competition that finished, so it gets its own
    /// count rather than being folded into `ended`.
    @Test func datelessLeadsAreCountedApartFromEndedOnes() {
        let rows = [
            competition(title: "Lead"),
            competition(title: "Over", startDate: ahead(-48), endDate: ahead(-24)),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.undated == 1)
        #expect(stats.ended == 1)
    }

    // MARK: breakdowns

    @Test func breakdownsAreRankedBiggestFirst() {
        let rows = [
            competition(title: "A", category: .ctf),
            competition(title: "B", category: .ctf),
            competition(title: "C", category: .hackathon),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.byCategory.first?.key == .ctf)
        #expect(stats.byCategory.first?.count == 2)
        #expect(stats.byCategory.map(\.count) == stats.byCategory.map(\.count).sorted(by: >))
    }

    @Test func groupsBySourceAndRegion() {
        let rows = [
            competition(title: "A", source: "ctftime", region: .vietnam),
            competition(title: "B", source: "ybox", region: .vietnam),
            competition(title: "C", source: "ybox", region: .global),
        ]
        let stats = DashboardStats(for: rows, now: now)
        #expect(stats.bySource.first == Tally(key: "ybox", count: 2))
        #expect(stats.byRegion.first == Tally(key: .vietnam, count: 2))
    }

    /// The same store must always render identically, or the dashboard appears
    /// to reshuffle itself between refreshes.
    @Test func tiesResolveTheSameWayEveryTime() {
        let rows = [
            competition(title: "A", source: "alpha"),
            competition(title: "B", source: "beta"),
        ]
        let first = DashboardStats(for: rows, now: now)
        let second = DashboardStats(for: rows.reversed(), now: now)
        #expect(first.bySource == second.bySource)
        #expect(first.byCategory == second.byCategory)
    }

    // MARK: empty

    @Test func anEmptyStoreProducesZeroesRatherThanNothing() {
        let stats = DashboardStats(for: [], now: now)
        #expect(stats.total == 0)
        #expect(stats.marked == 0)
        #expect(stats.byStatus.count == CompetitionStatus.allCases.count)
        #expect(stats.byStatus.allSatisfy { $0.count == 0 })
    }

    /// A view divides by this to size its bars.
    @Test func theBarScaleIsNeverZero() {
        #expect(DashboardStats.scale(for: [Tally<String>]()) == 1)
        #expect(DashboardStats.scale(for: [Tally(key: "a", count: 0)]) == 1)
        #expect(DashboardStats.scale(for: [Tally(key: "a", count: 7)]) == 7)
    }
}
