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

    // MARK: when it fires

    @Test func schedulesTheNextMorningsAtTheChosenHour() {
        let now = date(2026, 8, 2, 14, 30)
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 6))],
            hour: 8, calendar: calendar, now: now)
        #expect(plans.map(\.fireDate) == [date(2026, 8, 3, 8), date(2026, 8, 4, 8)])
    }

    /// Turning the digest on at 09:00 must not fire one for a morning that has
    /// already gone by.
    @Test func skipsAMorningThatHasAlreadyPassedToday() {
        let now = date(2026, 8, 2, 9, 0)
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 6))],
            hour: 8, calendar: calendar, now: now)
        #expect(plans.first?.fireDate == date(2026, 8, 3, 8))
        #expect(plans.allSatisfy { $0.fireDate > now })
    }

    @Test func honoursACustomHour() {
        let now = date(2026, 8, 2, 4, 0)
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 5))],
            hour: 6, minute: 30, daysAhead: 1, calendar: calendar, now: now)
        #expect(plans.map(\.fireDate) == [date(2026, 8, 2, 6, 30)])
    }

    // MARK: counts are relative to the morning, not to now

    /// The whole reason the counts are computed per morning. A deadline 8 days
    /// out is not "this week" today, but it is by tomorrow morning - and a
    /// digest that says otherwise when it fires is simply wrong.
    @Test func aDeadlineEntersTheWindowAsItsMorningApproaches() throws {
        let now = date(2026, 8, 2, 12, 0)
        // A long-running competition so BOTH mornings have something to say -
        // otherwise the first is skipped entirely and there is nothing to
        // compare against.
        let running = competition(
            title: "Running", startDate: date(2026, 7, 1), endDate: date(2026, 9, 1))
        let plans = DigestPlan.plans(
            for: [running, competition(registrationDeadline: date(2026, 8, 10, 12))],
            hour: 8, daysAhead: 2, calendar: calendar, now: now)

        // 3 Aug 08:00 + 7d = 10 Aug 08:00, which falls short of the deadline.
        let first = try #require(plans.first { $0.fireDate == date(2026, 8, 3, 8) })
        #expect(first.title == "Nothing closing this week")
        // 4 Aug 08:00 + 7d = 11 Aug 08:00, which now covers it.
        let second = try #require(plans.first { $0.fireDate == date(2026, 8, 4, 8) })
        #expect(second.title == "1 competition closing this week")
    }

    /// A skipped morning collapses out of the list rather than appearing as an
    /// empty plan, so what is scheduled is exactly what has something to say.
    @Test func quietMorningsAreAbsentRatherThanEmpty() {
        let now = date(2026, 8, 2, 12, 0)
        // Between 3 Aug's horizon (10 Aug 08:00) and 4 Aug's (11 Aug 08:00), so
        // only the second morning has anything to report.
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 10, 12))],
            hour: 8, daysAhead: 2, calendar: calendar, now: now)
        #expect(plans.map(\.fireDate) == [date(2026, 8, 4, 8)])
    }

    @Test func countsSeveralClosingCompetitions() {
        let now = date(2026, 8, 2, 12, 0)
        let rows = (1...3).map { index in
            competition(title: "Contest \(index)",
                        registrationDeadline: date(2026, 8, 5 + index))
        }
        let plans = DigestPlan.plans(
            for: rows, hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(plans[0].title == "3 competitions closing this week")
    }

    @Test func countsWhatIsRunningAtThatMorning() {
        let now = date(2026, 8, 2, 12, 0)
        let running = competition(
            title: "Running", startDate: date(2026, 8, 1), endDate: date(2026, 8, 20))
        let notYet = competition(
            title: "Later", startDate: date(2026, 8, 15), endDate: date(2026, 8, 25))
        let plans = DigestPlan.plans(
            for: [running, notYet], hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(plans[0].body.contains("1 running now"))
    }

    @Test func countsWhatWasFoundInTheLastDay() {
        let now = date(2026, 8, 2, 12, 0)
        let fresh = competition(title: "Fresh",
                                registrationDeadline: date(2026, 8, 6),
                                firstSeen: date(2026, 8, 2, 11))
        let old = competition(title: "Old",
                              registrationDeadline: date(2026, 8, 6),
                              firstSeen: date(2026, 7, 1))
        let plans = DigestPlan.plans(
            for: [fresh, old], hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(plans[0].body.contains("1 new since yesterday"))
    }

    /// Day one seeds the whole index at once. "282 new since yesterday" is true
    /// and useless, and it is exactly the noise the old per-refresh banner made.
    @Test func aFreshInstallDoesNotReportTheWholeIndexAsNew() {
        let now = date(2026, 8, 2, 12, 0)
        let justInstalled = (1...5).map { index in
            competition(title: "Contest \(index)",
                        registrationDeadline: date(2026, 8, 6),
                        firstSeen: date(2026, 8, 2, 11))
        }
        let plans = DigestPlan.plans(
            for: justInstalled, hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(!plans[0].body.contains("new"))
        #expect(plans[0].title == "5 competitions closing this week")
    }

    // MARK: silence

    /// The point of the digest is not to interrupt. A morning with nothing to
    /// report sends nothing, rather than "0 competitions this week".
    @Test func aMorningWithNothingToReportSendsNothing() {
        let now = date(2026, 8, 2, 12, 0)
        #expect(DigestPlan.plans(for: [], hour: 8, calendar: calendar, now: now).isEmpty)
    }

    @Test func anEmptyClauseIsOmittedRatherThanShownAsZero() {
        let now = date(2026, 8, 2, 12, 0)
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 6),
                              firstSeen: date(2026, 7, 1))],
            hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(plans[0].body == "")
        #expect(!plans[0].body.contains("0"))
    }

    // MARK: identity

    /// One digest per calendar day, so re-deriving on every refresh replaces
    /// that morning's plan instead of stacking a second one on it.
    @Test func oneStableIdentifierPerMorning() {
        let now = date(2026, 8, 2, 12, 0)
        let rows = [competition(registrationDeadline: date(2026, 8, 6))]
        let first = DigestPlan.plans(for: rows, hour: 8, calendar: calendar, now: now)
        let second = DigestPlan.plans(
            for: rows, hour: 8, calendar: calendar, now: now.addingTimeInterval(3600))
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first[0].id == "digest.2026-08-03")
        #expect(Set(first.map(\.id)).count == first.count)
    }

    /// The applier clears digests by prefix, so they must not collide with the
    /// reminder namespace or one would wipe the other.
    @Test func digestIdentifiersCannotBeMistakenForReminders() {
        let now = date(2026, 8, 2, 12, 0)
        let plans = DigestPlan.plans(
            for: [competition(registrationDeadline: date(2026, 8, 6))],
            hour: 8, calendar: calendar, now: now)
        #expect(plans.allSatisfy { $0.id.hasPrefix(DigestPlan.identifierPrefix) })
        #expect(plans.allSatisfy { !$0.id.hasPrefix(ReminderPlan.identifierPrefix) })
    }

    /// A digest is about the whole list, so marking must not change it. The two
    /// notification paths are independent by design.
    @Test func markingDoesNotChangeTheDigest() {
        let now = date(2026, 8, 2, 12, 0)
        let row = competition(registrationDeadline: date(2026, 8, 6))
        let before = DigestPlan.plans(
            for: [row], hour: 8, daysAhead: 1, calendar: calendar, now: now)
        row.status = .applied
        let after = DigestPlan.plans(
            for: [row], hour: 8, daysAhead: 1, calendar: calendar, now: now)
        #expect(before == after)
    }
}
