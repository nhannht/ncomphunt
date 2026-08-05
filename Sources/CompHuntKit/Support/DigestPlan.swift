import Foundation

/// The one notification the app sends about competitions you have NOT marked:
/// a short summary of the whole list, delivered when you get back to the
/// machine.
///
/// A separate path from `ReminderPlan`, not a variant of it. A reminder is keyed
/// to one competition's deadline; a digest has no competition at all. Squeezing
/// the second through the first would mean a fake competition or a nil-everywhere
/// field, so they only share the applier and their own identifier prefixes.
///
/// ```
///   every competition  ->  DigestPlan   ->  one post when you come back
///   marked only        ->  ReminderPlan ->  posts before a deadline
/// ```
///
/// ## When it arrives
///
/// This type says WHAT to send and never WHEN. The moment comes from
/// `ArrivalLog`, which watches for the user actually returning to the machine.
/// It used to be a wall-clock hour with a Settings picker, and that was wrong
/// twice over: the Mac is asleep at any hour you might name (measured
/// 2026-08-05 - deep sleep 07:51 to 08:06 swallowed the 08:00 post), and asking
/// someone to choose a time for a background app spends their attention on a
/// decision the app can make by watching.
///
/// Content is therefore computed at the moment it is used. There is no
/// scheduling-ahead and no stale-numbers hazard to reason about: a digest built
/// for `moment` describes the list as of `moment`.
public struct DigestPlan: Sendable, Equatable, Identifiable {
    /// Stable per day, so re-deriving replaces rather than duplicates.
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

    /// How wide "this week" is.
    public static let horizonDays = 7

    /// The digest for one moment, or nil when that moment has nothing to say.
    ///
    /// Every count is relative to `moment`, so the numbers are true when the
    /// post lands. macOS passes `.now` and posts immediately; iOS passes the
    /// next learned morning and schedules there. One constructor, two call
    /// shapes - the platforms differ in when they can reach the user, not in
    /// what the digest is.
    ///
    /// A moment with nothing to report yields no plan at all - the whole point
    /// is not to interrupt, and "0 competitions this week" is an interruption
    /// that carries no information.
    public static func make(
        for competitions: [Competition],
        at moment: Date,
        horizonDays: Int = horizonDays,
        calendar: Calendar = .current
    ) -> DigestPlan? {
        let closing = closingCount(in: competitions, from: moment,
                                   horizonDays: horizonDays)
        let running = runningCount(in: competitions, at: moment)
        let new = newCount(in: competitions, at: moment, calendar: calendar)
        guard closing > 0 || running > 0 || new > 0 else { return nil }
        return DigestPlan(
            id: identifier(for: moment, calendar: calendar),
            title: title(closing: closing, horizonDays: horizonDays),
            body: body(running: running, new: new),
            fireDate: moment)
    }

    /// Competitions whose next date falls between this moment and the horizon.
    static func closingCount(
        in competitions: [Competition], from moment: Date, horizonDays: Int
    ) -> Int {
        let limit = moment.addingTimeInterval(Double(horizonDays) * 86_400)
        return competitions.count { competition in
            guard let next = competition.nextRelevantDate else { return false }
            return next >= moment && next <= limit
        }
    }

    /// Already started and not yet over, as of that moment.
    static func runningCount(in competitions: [Competition], at moment: Date) -> Int {
        competitions.count { competition in
            guard let start = competition.startDate, start <= moment else { return false }
            guard let end = competition.endDate else { return false }
            return end >= moment
        }
    }

    /// First seen within a day of that moment.
    ///
    /// Reports nothing when EVERYTHING is new, which is the fresh install: the
    /// first refresh seeds the whole index at once, and "282 new since
    /// yesterday" is a true sentence carrying no information. "New" only means
    /// something against a baseline, and on day one there is not one yet.
    static func newCount(
        in competitions: [Competition], at moment: Date, calendar: Calendar
    ) -> Int {
        guard !competitions.isEmpty,
              let since = calendar.date(byAdding: .day, value: -1, to: moment)
        else { return 0 }
        let new = competitions.count { $0.firstSeen > since && $0.firstSeen <= moment }
        return new == competitions.count ? 0 : new
    }

    /// `digest.2026-08-03` - one per calendar day, which is what lets the app
    /// tell "already sent today" from "this is a new day" without a second
    /// piece of state.
    public static func identifier(for moment: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: moment)
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
