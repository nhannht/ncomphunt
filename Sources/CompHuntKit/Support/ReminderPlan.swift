import Foundation

/// One scheduled deadline reminder, computed here and handed to
/// `UNUserNotificationCenter` by the app layer. Same split as
/// `CalendarEventPlan`: the shaping rules are pure so they can be tested
/// without a notification centre, and the impure half stays a thin applier.
public struct ReminderPlan: Sendable, Equatable, Identifiable {
    /// Stable and idempotent: rescheduling the same competition at the same
    /// lead time produces the same identifier, so a re-apply replaces rather
    /// than duplicates.
    public let id: String
    /// The competition's dedupe key, so a tapped reminder can deep-link back.
    public let key: String
    public let title: String
    public let body: String
    public let fireDate: Date

    public init(id: String, key: String, title: String, body: String, fireDate: Date) {
        self.id = id
        self.key = key
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }

    /// One day out and one hour out. Fixed rather than configurable: two
    /// reminders is the pair that covers "start preparing" and "act now", and
    /// every extra lead time spends the notification budget below twice over.
    public static let defaultLeadTimes: [TimeInterval] = [24 * 3600, 3600]

    /// A ceiling, not a budget the person spends.
    ///
    /// iOS keeps only the 64 soonest-firing pending requests per app and
    /// silently discards the rest, so a cap has to exist. It is no longer a
    /// scarce resource competitions compete for: only marked ones schedule at
    /// all, and nobody marks 24 things. It exists so that if someone does, the
    /// app truncates deliberately instead of letting the OS drop requests
    /// silently, and Settings says so when it bites.
    public static let defaultLimit = 48

    /// The reminders that should be pending right now: every MARKED competition
    /// with a future deadline, soonest first.
    ///
    /// Marking is the entire subscription model. Before this, every upcoming
    /// competition was subscribed and people muted what they did not want -
    /// which meant the app interrupted about 282 things nobody asked about, and
    /// "quiet" was a chore you performed one row at a time. Opting in inverts
    /// that: silence is the default and a mark is a request to be told.
    ///
    /// `done` and `dropped` keep their mark but stop scheduling, via
    /// `wantsReminders`. A pipeline that kept notifying about finished things
    /// would get noisier the more it was used.
    ///
    /// Deliberately NOT scoped by the list's category/region lens. A lens is a
    /// transient browsing state and a reminder is a commitment; scoping one by
    /// the other means tapping a chip silently cancels reminders the person was
    /// relying on.
    ///
    /// Self-healing by construction: the whole set is re-derived from scratch
    /// on every refresh, so a newly marked competition joins immediately and an
    /// unmarked one drops out.
    public static func plans(
        for competitions: [Competition],
        leadTimes: [TimeInterval] = defaultLeadTimes,
        limit: Int = defaultLimit,
        now: Date = .now
    ) -> [ReminderPlan] {
        let upcoming = upcomingContests(
            in: competitions.filter(\.wantsReminders),
            category: nil, region: nil, now: now)

        var plans: [ReminderPlan] = []
        for competition in upcoming {
            guard let target = competition.nextRelevantDate else { continue }
            for lead in leadTimes {
                let fireDate = target.addingTimeInterval(-lead)
                // A lead time already in the past cannot be scheduled. Skipping
                // it rather than firing immediately is the point: a "1 day
                // before" alert delivered an hour before the deadline is a lie.
                guard fireDate > now else { continue }
                plans.append(ReminderPlan(
                    id: identifier(key: competition.key, lead: lead),
                    key: competition.key,
                    title: competition.title,
                    body: body(for: competition, target: target, at: fireDate),
                    fireDate: fireDate))
            }
        }

        // Soonest first, then truncate: if the ceiling is ever reached, it is
        // the nearest deadlines that survive.
        return Array(plans.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    /// `reminder.<key>.<lead seconds>` - the `reminder.` prefix is what lets the
    /// applier find and clear exactly its own pending requests, leaving the
    /// immediate posts alone.
    public static let identifierPrefix = "reminder."

    static func identifier(key: String, lead: TimeInterval) -> String {
        "\(identifierPrefix)\(key).\(Int(lead))"
    }

    /// Reads in the same language as the menu-bar countdown, via the shared
    /// `compactCountdown`, so "2d" means the same thing on every surface.
    static func body(for competition: Competition, target: Date, at fireDate: Date) -> String {
        let lead = compactCountdown(to: target, now: fireDate)
        var parts: [String]
        if competition.registrationDeadline != nil {
            parts = ["Registration closes in \(lead)"]
        } else if let start = competition.startDate, start == target {
            parts = ["Starts in \(lead)"]
        } else {
            parts = ["Ends in \(lead)"]
        }
        if !competition.prize.isEmpty {
            parts.append(competition.prize)
        }
        return parts.joined(separator: " · ")
    }
}
