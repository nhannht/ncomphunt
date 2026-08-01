import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct ReminderPlanTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func competition(
        title: String = "Sample Contest",
        url: String = "https://example.com/contest",
        prize: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, organizer: "", url: url,
            location: "", prize: prize, startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        return Competition(dto: dto, category: .other, region: .global, now: now)
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

    @Test func mutedKeyIsExcluded() {
        let kept = competition(
            title: "Kept", url: "https://example.com/a",
            registrationDeadline: ahead(72))
        let muted = competition(
            title: "Muted", url: "https://example.com/b",
            registrationDeadline: ahead(72))
        let plans = ReminderPlan.plans(
            for: [kept, muted], muted: [muted.key], now: now)
        #expect(plans.allSatisfy { $0.key == kept.key })
        #expect(plans.count == 2)
    }

    // MARK: the budget

    /// The cap is on notifications, not competitions, and it must go to the
    /// reminders that fire NEXT - whichever competition they belong to.
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

    /// Muting frees budget: the next competition rolls into the window.
    @Test func mutingLetsTheNextCompetitionRollIn() {
        let competitions = (1...4).map { index in
            competition(
                title: "Contest \(index)",
                url: "https://example.com/\(index)",
                registrationDeadline: ahead(48 + Double(index)))
        }
        let full = ReminderPlan.plans(for: competitions, limit: 4, now: now)
        let muted = ReminderPlan.plans(
            for: competitions, muted: [competitions[0].key], limit: 4, now: now)
        #expect(full.count == 4)
        #expect(muted.count == 4)
        // The dropped competition's slots are refilled by one further out.
        #expect(muted.contains { $0.key == competitions[3].key })
        #expect(muted.allSatisfy { $0.key != competitions[0].key })
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
