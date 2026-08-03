import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct ContestActivityPlanTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func competition(
        title: String = "Sample Contest",
        url: String = "https://example.com/contest",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, organizer: "", url: url,
            location: "", prize: "", startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        return Competition(dto: dto, tags: [.ctf], region: .global, now: now)
    }

    /// `hours` from the frozen `now`.
    private func ahead(_ hours: Double) -> Date {
        now.addingTimeInterval(hours * 3600)
    }

    // MARK: face selection

    /// The deadline is the more urgent of the two dates, same order as
    /// `nextRelevantDate`.
    @Test func deadlineOutranksStart() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(48), registrationDeadline: ahead(24)),
            now: now)
        #expect(plan?.state.phase == .registration)
        #expect(plan?.state.target == ahead(24))
        #expect(plan?.staleDate == ahead(24))
    }

    @Test func startWhenNoDeadline() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(5), endDate: ahead(9)), now: now)
        #expect(plan?.state.phase == .preStart)
        #expect(plan?.state.target == ahead(5))
        #expect(plan?.staleDate == ahead(5))
    }

    /// A closed registration is not a reason to stop following: the face
    /// falls through to the next date that matters.
    @Test func pastDeadlineFallsThroughToStart() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(3), registrationDeadline: ahead(-1)),
            now: now)
        #expect(plan?.state.phase == .preStart)
        #expect(plan?.state.target == ahead(3))
    }

    // MARK: the running face and the cap

    @Test func runningWithinCapCountsDownToTheEnd() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(-1), endDate: ahead(2)), now: now)
        #expect(plan?.state.phase == .running)
        #expect(plan?.state.target == ahead(2))
        #expect(plan?.state.start == ahead(-1))
        #expect(plan?.state.end == ahead(2))
        #expect(plan?.staleDate == ahead(2))
    }

    /// A contest exactly as long as the cap still fits inside it.
    @Test func runningExactlyAtCapStillShows() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(-1), endDate: ahead(7)), now: now)
        #expect(plan?.state.phase == .running)
    }

    /// A 48-hour CTF mid-run has no face: the system would cut the activity
    /// off anyway, so the plan never offers it.
    @Test func runningBeyondCapReturnsNil() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(-24), endDate: ahead(24)), now: now)
        #expect(plan == nil)
    }

    /// The cap only kills the RUNNING face. Before the start, a multi-day
    /// event counts down like any other.
    @Test func multiDayEventStillCountsDownToStart() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(2), endDate: ahead(50)), now: now)
        #expect(plan?.state.phase == .preStart)
        #expect(plan?.state.target == ahead(2))
    }

    // MARK: nothing to follow

    @Test func datelessReturnsNil() {
        #expect(ContestActivityPlan.plan(for: competition(), now: now) == nil)
    }

    @Test func endedReturnsNil() {
        let ended = competition(startDate: ahead(-48), endDate: ahead(-24))
        #expect(ContestActivityPlan.plan(for: ended, now: now) == nil)
    }

    /// Started with no known end: the pre-start countdown was its only face.
    @Test func startedWithoutEndReturnsNil() {
        let plan = ContestActivityPlan.plan(
            for: competition(startDate: ahead(-1)), now: now)
        #expect(plan == nil)
    }

    // MARK: shared wording and attributes

    @Test func phaseCountdownLabels() {
        #expect(ContestActivityAttributes.ContentState.Phase
            .registration.countdownLabel == "Registration closes")
        #expect(ContestActivityAttributes.ContentState.Phase
            .preStart.countdownLabel == "Starts")
        #expect(ContestActivityAttributes.ContentState.Phase
            .running.countdownLabel == "Ends")
    }

    @Test func attributesCarryTheCategoryShortCode() {
        let attributes = ContestActivityAttributes(
            competition: competition(title: "picoCTF"))
        #expect(attributes.title == "picoCTF")
        #expect(attributes.categoryCode == "CTF")
        #expect(!attributes.key.isEmpty)
    }
}
