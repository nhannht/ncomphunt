import Foundation

/// The one notification the app sends about competitions you have NOT marked:
/// a short morning summary of the whole list.
///
/// A separate path from `ReminderPlan`, not a variant of it. A reminder is keyed
/// to one competition's deadline; a digest is keyed to a wall-clock hour and has
/// no competition at all. Squeezing the second through the first would mean a
/// fake competition or a nil-everywhere field, so they only share the applier
/// and their own identifier prefixes.
///
/// ```
///   every competition  ->  DigestPlan   ->  one post each morning
///   marked only        ->  ReminderPlan ->  posts before a deadline
/// ```
public struct DigestPlan: Sendable, Equatable, Identifiable {
    /// Stable per morning, so re-applying replaces rather than duplicates.
    public let id: String
    public let title: String
    public let body: String
    public let fireDate: Date

    public init(id: String, title: String, body: String, fireDate: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }

    /// `digest.` is what lets the applier clear its own pending requests without
    /// touching the deadline reminders that live beside them.
    public static let identifierPrefix = "digest."

    /// The default morning. Changeable in Settings, because "morning" is
    /// personal and a digest that arrives after someone starts work is just a
    /// notification.
    public static let defaultHour = 8
    public static let defaultMinute = 0

    /// How far ahead to schedule.
    ///
    /// Two mornings, not thirty. Content is computed when the plan is built, so
    /// a digest scheduled far out describes a list that has since changed. Two
    /// covers a day the app never runs, and every refresh re-derives the pair.
    /// If the app stays closed longer than that the digest goes quiet, which is
    /// the honest failure - better than arriving with week-old numbers.
    public static let defaultDaysAhead = 2

    /// How wide "this week" is.
    public static let horizonDays = 7

    /// The digests that should be pending right now.
    ///
    /// Each morning's counts are computed relative to THAT morning, not to now,
    /// so tomorrow's digest is accurate when it fires rather than describing
    /// today. A morning with nothing to report yields no plan at all - the whole
    /// point is not to interrupt, and "0 competitions this week" is an
    /// interruption that carries no information.
    public static func plans(
        for competitions: [Competition],
        hour: Int = defaultHour,
        minute: Int = defaultMinute,
        daysAhead: Int = defaultDaysAhead,
        horizonDays: Int = horizonDays,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [DigestPlan] {
        var plans: [DigestPlan] = []
        for morning in mornings(hour: hour, minute: minute, count: daysAhead,
                                calendar: calendar, now: now) {
            let closing = closingCount(in: competitions, from: morning,
                                       horizonDays: horizonDays)
            let running = runningCount(in: competitions, at: morning)
            // `new` is only meaningful for the first morning and only counts
            // what is already known: anything discovered between now and then
            // is not in the store yet. Every refresh rebuilds these plans, so
            // by the time one fires it under-counts by at most one refresh.
            let new = newCount(in: competitions, at: morning, calendar: calendar)

            guard closing > 0 || running > 0 || new > 0 else { continue }
            plans.append(DigestPlan(
                id: identifier(for: morning, calendar: calendar),
                title: title(closing: closing, horizonDays: horizonDays),
                body: body(running: running, new: new),
                fireDate: morning))
        }
        return plans
    }

    /// The next `count` occurrences of the given local time, strictly in the
    /// future. Today's is skipped once it has passed, so enabling the digest at
    /// 9am does not fire one immediately for a morning already gone.
    static func mornings(
        hour: Int, minute: Int, count: Int, calendar: Calendar, now: Date
    ) -> [Date] {
        var results: [Date] = []
        var day = now
        // One extra day of headroom: today's slot is usually already past.
        for _ in 0...(count) {
            guard let candidate = calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day)
            else { break }
            if candidate > now { results.append(candidate) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day)
            else { break }
            day = next
            if results.count == count { break }
        }
        return results
    }

    /// Competitions whose next date falls between this morning and the horizon.
    static func closingCount(
        in competitions: [Competition], from morning: Date, horizonDays: Int
    ) -> Int {
        let limit = morning.addingTimeInterval(Double(horizonDays) * 86_400)
        return competitions.count { competition in
            guard let next = competition.nextRelevantDate else { return false }
            return next >= morning && next <= limit
        }
    }

    /// Already started and not yet over, as of that morning.
    static func runningCount(in competitions: [Competition], at morning: Date) -> Int {
        competitions.count { competition in
            guard let start = competition.startDate, start <= morning else { return false }
            guard let end = competition.endDate else { return false }
            return end >= morning
        }
    }

    /// First seen within a day of that morning.
    ///
    /// Reports nothing when EVERYTHING is new, which is the fresh install: the
    /// first refresh seeds the whole index at once, and "282 new since
    /// yesterday" is a true sentence carrying no information. "New" only means
    /// something against a baseline, and on day one there is not one yet.
    static func newCount(
        in competitions: [Competition], at morning: Date, calendar: Calendar
    ) -> Int {
        guard !competitions.isEmpty,
              let since = calendar.date(byAdding: .day, value: -1, to: morning)
        else { return 0 }
        let new = competitions.count { $0.firstSeen > since && $0.firstSeen <= morning }
        return new == competitions.count ? 0 : new
    }

    /// `digest.2026-08-03` - one per calendar day, so rebuilding the set
    /// replaces that morning's plan instead of stacking a second one on it.
    static func identifier(for morning: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: morning)
        return String(format: "%@%04d-%02d-%02d", identifierPrefix,
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func title(closing: Int, horizonDays: Int) -> String {
        guard closing > 0 else { return "Nothing closing this week" }
        let window = horizonDays == 7 ? "this week" : "in \(horizonDays) days"
        return "\(closing) competition\(closing == 1 ? "" : "s") closing \(window)"
    }

    /// Only the parts that have something to say. A body listing zeroes reads
    /// as a form rather than as news.
    static func body(running: Int, new: Int) -> String {
        var parts: [String] = []
        if running > 0 { parts.append("\(running) running now") }
        if new > 0 { parts.append("\(new) new since yesterday") }
        return parts.joined(separator: " \u{00B7} ")
    }
}
