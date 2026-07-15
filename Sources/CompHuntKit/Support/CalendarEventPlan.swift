import Foundation

/// The shape of a single calendar event for a competition, computed once and
/// consumed by both the one-off `.ics` export (`ICSBuilder`) and the live
/// EventKit sync (`CalendarSyncService`) so the two surfaces can never drift.
///
/// This is the single source of truth for "how a competition becomes an event":
/// which date anchors it, the title, the reminder, and the note body.
public struct CalendarEventPlan: Sendable, Equatable {
    /// Stable identity (the competition's dedupe key). The sync layer maps this
    /// to an `EKEvent` identifier; the `.ics` layer uses it as the VEVENT UID.
    public let key: String
    public let title: String
    public let start: Date
    public let end: Date
    /// Note lines already joined with `\n` (URL, organizer, prize, provenance).
    public let notes: String
    public let url: String
    public let location: String
    /// Reminder offset before `start`, in seconds (negative). One day out,
    /// matching the `.ics` VALARM.
    public let alarmOffset: TimeInterval

    public init(
        key: String, title: String, start: Date, end: Date,
        notes: String, url: String, location: String, alarmOffset: TimeInterval
    ) {
        self.key = key
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.url = url
        self.location = location
        self.alarmOffset = alarmOffset
    }

    /// Build a plan from a competition, or `nil` when there is no date to anchor
    /// an event on. An explicit start wins; otherwise a registration deadline
    /// becomes a one-hour block ending at the deadline, titled
    /// "Deadline: <title>". Identical shaping to the `.ics` export.
    public static func plan(for competition: Competition, now: Date = .now) -> CalendarEventPlan? {
        let title: String
        let start: Date
        let end: Date
        if let eventStart = competition.startDate {
            title = competition.title
            start = eventStart
            end = competition.endDate ?? eventStart.addingTimeInterval(2 * 3600)
        } else if let deadline = competition.registrationDeadline {
            title = "Deadline: \(competition.title)"
            start = deadline.addingTimeInterval(-3600)
            end = deadline
        } else {
            return nil
        }

        var notes = ["URL: \(competition.url)"]
        if !competition.organizer.isEmpty {
            notes.append("Organizer: \(competition.organizer)")
        }
        if !competition.prize.isEmpty {
            notes.append("Prize: \(competition.prize)")
        }
        notes.append("Found via \(competition.source) (nCompHunt)")

        return CalendarEventPlan(
            key: competition.key,
            title: title,
            start: start,
            end: end,
            notes: notes.joined(separator: "\n"),
            url: competition.url,
            location: competition.location,
            alarmOffset: -24 * 3600)
    }
}

/// A pure reconcile between the desired calendar events (keyed by competition
/// key) and the keys already present in the dedicated calendar. The impure
/// EventKit layer applies the result; keeping the partitioning here makes the
/// "auto-updating" core unit-testable without a live event store.
public struct CalendarSyncDiff: Sendable, Equatable {
    /// Desired keys with no event yet.
    public let toCreate: [CalendarEventPlan]
    /// Desired keys that already have an event: refresh it in place (this is
    /// what fixes a stale import when a contest date moves).
    public let toUpdate: [CalendarEventPlan]
    /// Tracked keys no longer desired (contest ended, pruned, or removed):
    /// delete their events. Sorted for deterministic application and testing.
    public let toDelete: [String]

    public init(toCreate: [CalendarEventPlan], toUpdate: [CalendarEventPlan], toDelete: [String]) {
        self.toCreate = toCreate
        self.toUpdate = toUpdate
        self.toDelete = toDelete
    }

    public static func compute(
        desired: [CalendarEventPlan],
        existingKeys: Set<String>
    ) -> CalendarSyncDiff {
        var create: [CalendarEventPlan] = []
        var update: [CalendarEventPlan] = []
        var desiredKeys: Set<String> = []
        for plan in desired {
            desiredKeys.insert(plan.key)
            if existingKeys.contains(plan.key) {
                update.append(plan)
            } else {
                create.append(plan)
            }
        }
        let delete = existingKeys.subtracting(desiredKeys).sorted()
        return CalendarSyncDiff(toCreate: create, toUpdate: update, toDelete: delete)
    }
}
