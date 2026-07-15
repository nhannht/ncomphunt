import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct CalendarEventPlanTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func competition(
        source: String = "fake",
        title: String = "Sample Contest",
        organizer: String = "",
        url: String = "https://example.com/contest",
        location: String = "",
        prize: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: source, title: title, organizer: organizer, url: url,
            location: location, prize: prize, startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        return Competition(dto: dto, category: .other, region: .global, now: now)
    }

    // MARK: plan shaping (mirrors ICSBuilder so the .ics and EventKit agree)

    @Test func explicitDatesBoundTheEvent() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-08-03T18:00:00Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(startDate: start, endDate: end), now: now))
        #expect(plan.title == "Sample Contest")
        #expect(plan.start == start)
        #expect(plan.end == end)
    }

    @Test func missingEndDefaultsToTwoHours() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(startDate: start), now: now))
        #expect(plan.start == start)
        #expect(plan.end == start.addingTimeInterval(2 * 3600))
    }

    @Test func deadlineOnlyBecomesOneHourBlock() throws {
        let deadline = ISO8601DateFormatter().date(from: "2026-07-28T16:59:59Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(registrationDeadline: deadline), now: now))
        #expect(plan.title == "Deadline: Sample Contest")
        #expect(plan.end == deadline)
        #expect(plan.start == deadline.addingTimeInterval(-3600))
    }

    @Test func startWinsOverDeadline() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let deadline = ISO8601DateFormatter().date(from: "2026-07-28T16:59:59Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(startDate: start, registrationDeadline: deadline), now: now))
        #expect(plan.title == "Sample Contest")
        #expect(plan.start == start)
    }

    @Test func datelessReturnsNil() {
        #expect(CalendarEventPlan.plan(for: competition(), now: now) == nil)
    }

    @Test func notesCarryProvenanceAndOptionalFields() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(
                source: "ctftime", organizer: "ACME", prize: "$5000",
                startDate: start),
            now: now))
        #expect(plan.notes.contains("URL: https://example.com/contest"))
        #expect(plan.notes.contains("Organizer: ACME"))
        #expect(plan.notes.contains("Prize: $5000"))
        #expect(plan.notes.contains("Found via ctftime (nCompHunt)"))
    }

    @Test func notesOmitEmptyOptionalFields() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let plan = try #require(CalendarEventPlan.plan(
            for: competition(startDate: start), now: now))
        #expect(!plan.notes.contains("Organizer:"))
        #expect(!plan.notes.contains("Prize:"))
    }

    @Test func keyMatchesCompetitionKey() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let comp = competition(url: "https://Example.com/Contest/?ref=x", startDate: start)
        let plan = try #require(CalendarEventPlan.plan(for: comp, now: now))
        #expect(plan.key == comp.key)
        #expect(plan.key == "https://example.com/contest")
    }

    // MARK: diff partitioning (the auto-updating core)

    private func plan(key: String) -> CalendarEventPlan {
        CalendarEventPlan(
            key: key, title: key, start: now, end: now.addingTimeInterval(3600),
            notes: "", url: "https://example.com/\(key)", location: "", alarmOffset: -24 * 3600)
    }

    @Test func diffCreatesWhenNoExistingEvent() {
        let diff = CalendarSyncDiff.compute(
            desired: [plan(key: "a"), plan(key: "b")], existingKeys: [])
        #expect(diff.toCreate.map(\.key) == ["a", "b"])
        #expect(diff.toUpdate.isEmpty)
        #expect(diff.toDelete.isEmpty)
    }

    @Test func diffUpdatesWhenEventPresent() {
        let diff = CalendarSyncDiff.compute(
            desired: [plan(key: "a")], existingKeys: ["a"])
        #expect(diff.toCreate.isEmpty)
        #expect(diff.toUpdate.map(\.key) == ["a"])
        #expect(diff.toDelete.isEmpty)
    }

    @Test func diffDeletesUntrackedAndSortsThem() {
        let diff = CalendarSyncDiff.compute(
            desired: [plan(key: "keep")], existingKeys: ["keep", "gone-b", "gone-a"])
        #expect(diff.toUpdate.map(\.key) == ["keep"])
        #expect(diff.toDelete == ["gone-a", "gone-b"])
        #expect(diff.toCreate.isEmpty)
    }

    @Test func diffMixedCreateUpdateDelete() {
        let diff = CalendarSyncDiff.compute(
            desired: [plan(key: "new"), plan(key: "existing")],
            existingKeys: ["existing", "stale"])
        #expect(diff.toCreate.map(\.key) == ["new"])
        #expect(diff.toUpdate.map(\.key) == ["existing"])
        #expect(diff.toDelete == ["stale"])
    }
}
