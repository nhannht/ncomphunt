import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct DigestPlanTests {
    /// A fixed calendar so the tests do not move with the machine's timezone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func competition(
        title: String = "Contest",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil,
        firstSeen: Date? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, organizer: "",
            url: "https://example.com/\(title)", location: "", prize: "",
            startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        return Competition(dto: dto, tags: [], region: .global,
                           now: firstSeen ?? date(2020, 1, 1))
    }

    // MARK: counts are relative to the moment it is built for

    /// The whole reason the counts are computed per moment. A deadline 8 days
    /// out is not "this week" today, but it is by tomorrow - and a digest that
    /// says otherwise when it lands is simply wrong.
    @Test func aDeadlineEntersTheWindowAsItsMomentApproaches() throws {
        // A long-running competition so BOTH moments have something to say -
        // otherwise the first yields no plan and there is nothing to compare.
        let running = competition(
            title: "Running", startDate: date(2026, 7, 1), endDate: date(2026, 9, 1))
        let rows = [running, competition(registrationDeadline: date(2026, 8, 10, 12))]

        // 3 Aug 08:00 + 7d = 10 Aug 08:00, which falls short of the deadline.
        let earlier = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 3, 8), calendar: calendar))
        #expect(earlier.title == "Nothing closing this week")
        // 4 Aug 08:00 + 7d = 11 Aug 08:00, which now covers it.
        let later = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 4, 8), calendar: calendar))
        #expect(later.title == "1 competition closing this week")
    }

    @Test func countsSeveralClosingCompetitions() throws {
        let rows = (1...3).map { index in
            competition(title: "Contest \(index)",
                        registrationDeadline: date(2026, 8, 5 + index))
        }
        let plan = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(plan.title == "3 competitions closing this week")
    }

    @Test func countsWhatIsRunningAtThatMoment() throws {
        let running = competition(
            title: "Running", startDate: date(2026, 8, 1), endDate: date(2026, 8, 20))
        let notYet = competition(
            title: "Later", startDate: date(2026, 8, 15), endDate: date(2026, 8, 25))
        let plan = try #require(DigestPlan.make(
            for: [running, notYet], at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(plan.body.contains("1 running now"))
    }

    @Test func countsWhatWasFoundInTheLastDay() throws {
        let fresh = competition(title: "Fresh",
                                registrationDeadline: date(2026, 8, 6),
                                firstSeen: date(2026, 8, 2, 11))
        let old = competition(title: "Old",
                              registrationDeadline: date(2026, 8, 6),
                              firstSeen: date(2026, 7, 1))
        let plan = try #require(DigestPlan.make(
            for: [fresh, old], at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(plan.body.contains("1 new since yesterday"))
    }

    /// Day one seeds the whole index at once. "282 new since yesterday" is true
    /// and useless, and it is exactly the noise the old per-refresh banner made.
    @Test func aFreshInstallDoesNotReportTheWholeIndexAsNew() throws {
        let justInstalled = (1...5).map { index in
            competition(title: "Contest \(index)",
                        registrationDeadline: date(2026, 8, 6),
                        firstSeen: date(2026, 8, 2, 11))
        }
        let plan = try #require(DigestPlan.make(
            for: justInstalled, at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(!plan.body.contains("new"))
        #expect(plan.title == "5 competitions closing this week")
    }

    // MARK: silence

    /// The point of the digest is not to interrupt. A moment with nothing to
    /// report sends nothing, rather than "0 competitions this week".
    @Test func aMomentWithNothingToReportSendsNothing() {
        #expect(DigestPlan.make(for: [], at: date(2026, 8, 2, 12),
                                calendar: calendar) == nil)
    }

    /// Between 2 Aug's horizon and the deadline, so this moment has nothing to
    /// say at all - and says nothing, rather than an empty plan.
    @Test func aQuietHorizonYieldsNoPlanRatherThanAnEmptyOne() {
        #expect(DigestPlan.make(
            for: [competition(registrationDeadline: date(2026, 8, 20))],
            at: date(2026, 8, 2, 12), calendar: calendar) == nil)
    }

    @Test func anEmptyClauseIsOmittedRatherThanShownAsZero() throws {
        let plan = try #require(DigestPlan.make(
            for: [competition(registrationDeadline: date(2026, 8, 6),
                              firstSeen: date(2026, 7, 1))],
            at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(plan.body == "")
        #expect(!plan.body.contains("0"))
    }

    // MARK: identity

    /// One digest per calendar day. This is what lets the app tell "already sent
    /// today" from "this is a new day" without keeping a second piece of state,
    /// so two moments on the same day must agree.
    @Test func oneStableIdentifierPerDay() throws {
        let rows = [competition(registrationDeadline: date(2026, 8, 6))]
        let morning = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 2, 9), calendar: calendar))
        let evening = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 2, 21), calendar: calendar))
        #expect(morning.id == evening.id)
        #expect(morning.id == "digest.2026-08-02")

        let nextDay = try #require(
            DigestPlan.make(for: rows, at: date(2026, 8, 3, 9), calendar: calendar))
        #expect(nextDay.id == "digest.2026-08-03")
    }

    /// The applier clears digests by prefix, so they must not collide with the
    /// reminder namespace or one would wipe the other.
    @Test func digestIdentifiersCannotBeMistakenForReminders() throws {
        let plan = try #require(DigestPlan.make(
            for: [competition(registrationDeadline: date(2026, 8, 6))],
            at: date(2026, 8, 2, 12), calendar: calendar))
        #expect(plan.id.hasPrefix(DigestPlan.identifierPrefix))
        #expect(!plan.id.hasPrefix(ReminderPlan.identifierPrefix))
    }

    /// The moment it is built for is the moment it fires. macOS passes now and
    /// posts; iOS passes the next learned morning and schedules there.
    @Test func theFireDateIsTheMomentItWasBuiltFor() throws {
        let moment = date(2026, 8, 6, 9, 15)
        let plan = try #require(DigestPlan.make(
            for: [competition(registrationDeadline: date(2026, 8, 8))],
            at: moment, calendar: calendar))
        #expect(plan.fireDate == moment)
    }

    /// A digest is about the whole list, so marking must not change it. The two
    /// notification paths are independent by design.
    @Test func markingDoesNotChangeTheDigest() throws {
        let row = competition(registrationDeadline: date(2026, 8, 6))
        let before = DigestPlan.make(for: [row], at: date(2026, 8, 2, 12),
                                     calendar: calendar)
        row.status = .applied
        let after = DigestPlan.make(for: [row], at: date(2026, 8, 2, 12),
                                    calendar: calendar)
        #expect(before == after)
    }
}
