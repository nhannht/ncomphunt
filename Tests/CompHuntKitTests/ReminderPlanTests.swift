import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct ReminderPlanTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    /// Marked by default, because only a marked competition schedules anything
    /// and the tests below are about lead times, the ceiling, and body copy -
    /// marking is their precondition, not their subject. What marking itself
    /// decides is tested in "what earns a reminder".
    private func competition(
        title: String = "Sample Contest",
        url: String = "https://example.com/contest",
        prize: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil,
        status: CompetitionStatus? = .interested
    ) -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, organizer: "", url: url,
            location: "", prize: prize, startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        let row = Competition(dto: dto, tags: [], region: .global, now: now)
        row.status = status
        return row
    }

    /// `hours` from the frozen `now`.
    private func ahead(_ hours: Double) -> Date {
        now.addingTimeInterval(hours * 3600)
    }

    // MARK: lead times

    @Test func schedulesBothLeadTimesForADistantDeadline() {
        let plans = ReminderPlan.plans(
            for: [competition(registrationDeadline: ahead(72))], now: now)
        #expect(plans.count == 2)
        #expect(plans.map(\.fireDate) == [ahead(48), ahead(71)])
    }

    /// A "1 day before" alert delivered an hour before the deadline is a lie,
    /// so a lead time already in the past is dropped, not fired late.
    @Test func dropsALeadTimeAlreadyInThePast() {
        let plans = ReminderPlan.plans(
            for: [competition(registrationDeadline: ahead(5))], now: now)
        #expect(plans.count == 1)
        #expect(plans[0].fireDate == ahead(4))
    }

    @Test func schedulesNothingWhenEveryLeadTimeHasPassed() {
        let plans = ReminderPlan.plans(
            for: [competition(registrationDeadline: ahead(0.5))], now: now)
        #expect(plans.isEmpty)
    }

    // MARK: what earns a reminder

    @Test func datelessCompetitionGetsNoReminder() {
        #expect(ReminderPlan.plans(for: [competition()], now: now).isEmpty)
    }

    @Test func endedCompetitionGetsNoReminder() {
        let ended = competition(
            startDate: ahead(-72), endDate: ahead(-48))
        #expect(ReminderPlan.plans(for: [ended], now: now).isEmpty)
    }

    /// The whole subscription model in one test. Silence is the default; a mark
    /// is a request to be told. This replaces the retired opt-out pair
    /// (`mutedKeyIsExcluded`, `mutingLetsTheNextCompetitionRollIn`), which
    /// asserted the opposite - that everything was subscribed until muted.
    @Test func onlyMarkedCompetitionsAreScheduled() {
        let marked = competition(
            title: "Marked", url: "https://example.com/a",
            registrationDeadline: ahead(72), status: .interested)
        let unmarked = competition(
            title: "Unmarked", url: "https://example.com/b",
            registrationDeadline: ahead(72), status: nil)
        let plans = ReminderPlan.plans(for: [marked, unmarked], now: now)
        #expect(plans.count == 2)
        #expect(plans.allSatisfy { $0.key == marked.key })
    }

    @Test func aListWithNothingMarkedSchedulesNothingAtAll() {
        let rows = (1...20).map { index in
            competition(title: "Contest \(index)",
                        url: "https://example.com/\(index)",
                        registrationDeadline: ahead(48 + Double(index)),
                        status: nil)
        }
        #expect(ReminderPlan.plans(for: rows, now: now).isEmpty)
    }

    /// A pipeline that kept notifying about finished competitions would get
    /// noisier the more it was used, so the terminal states keep the mark and
    /// drop the reminders.
    @Test func finishedAndAbandonedStatesKeepTheMarkButStopScheduling() {
        for status in [CompetitionStatus.done, .dropped] {
            let row = competition(registrationDeadline: ahead(72), status: status)
            #expect(row.isMarked)
            #expect(ReminderPlan.plans(for: [row], now: now).isEmpty)
        }
        for status in [CompetitionStatus.interested, .applied, .joined] {
            let row = competition(registrationDeadline: ahead(72), status: status)
            #expect(ReminderPlan.plans(for: [row], now: now).count == 2)
        }
    }

    /// Unmarking has to take the pending reminders with it, or turning
    /// something off leaves it still shouting.
    @Test func unmarkingRemovesItsReminders() {
        let row = competition(registrationDeadline: ahead(72))
        #expect(ReminderPlan.plans(for: [row], now: now).count == 2)
        row.status = nil
        #expect(ReminderPlan.plans(for: [row], now: now).isEmpty)
    }

    // MARK: the ceiling

    /// Reaching this now takes 24 marked competitions, so it is a backstop
    /// rather than something people run into. It still has to truncate
    /// deliberately: iOS silently drops everything past its own 64, and the
    /// nearest deadlines are the ones worth keeping.
    @Test func capKeepsTheSoonestFiring() {
        let competitions = (1...10).map { index in
            competition(
                title: "Contest \(index)",
                url: "https://example.com/\(index)",
                registrationDeadline: ahead(48 + Double(index)))
        }
        let plans = ReminderPlan.plans(for: competitions, limit: 5, now: now)
        #expect(plans.count == 5)
        #expect(plans == plans.sorted { $0.fireDate < $1.fireDate })
        let cutoff = try? #require(plans.last).fireDate
        let all = ReminderPlan.plans(for: competitions, limit: .max, now: now)
        #expect(all.filter { $0.fireDate < cutoff! }.count == 4)
    }

    // MARK: identity

    /// Rescheduling must replace, never duplicate.
    @Test func identifiersAreStableAcrossRuns() {
        let target = [competition(registrationDeadline: ahead(72))]
        let first = ReminderPlan.plans(for: target, now: now)
        let second = ReminderPlan.plans(for: target, now: now)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(Set(first.map(\.id)).count == first.count)
        #expect(first.allSatisfy { $0.id.hasPrefix(ReminderPlan.identifierPrefix) })
    }

    // MARK: body copy

    @Test func bodyNamesTheDeadlineAndPrize() throws {
        let plans = ReminderPlan.plans(
            for: [competition(prize: "$4,000", registrationDeadline: ahead(72))],
            now: now)
        let dayBefore = try #require(plans.first)
        #expect(dayBefore.body == "Registration closes in 1d · $4,000")
    }

    @Test func bodyNamesTheStartWhenThereIsNoDeadline() throws {
        let plans = ReminderPlan.plans(
            for: [competition(startDate: ahead(72))], now: now)
        let dayBefore = try #require(plans.first)
        #expect(dayBefore.body == "Starts in 1d")
    }
}
