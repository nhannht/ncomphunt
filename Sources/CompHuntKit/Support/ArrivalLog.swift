import Foundation

/// When the user comes back to the machine, learned by watching rather than by
/// asking. The pure half of the digest's timing, the same split `ReminderPlan`
/// and `CalendarEventPlan` use: this decides, the app layer samples and applies.
///
/// ```
///   presence samples  ->  ArrivalLog  ->  "they just got back"   (macOS posts now)
///                                     ->  "their morning is ~9am" (iOS schedules)
/// ```
///
/// ## Why this exists
///
/// The digest used to fire at a wall-clock hour. On 2026-08-05 it was set to
/// 08:00 and the Mac was in deep sleep from 07:51 to 08:06, so the moment passed
/// with the machine down. That is not bad luck: this Mac is clamshell-asleep
/// every night, so any fixed instant misses by construction. The fix is to stop
/// naming a time and start noticing an arrival.
///
/// ## Rules that are easy to violate later
///
/// - **App liveness is NOT user presence.** A sleeping Mac dark-wakes every few
///   minutes all night and the app logs activity through every one of them
///   (measured 2026-08-05: 02:41, 06:32, 07:38, 07:49, 08:06 ...). A design keyed
///   to "time since the app last ticked" fires the digest at 02:41. The caller
///   must only feed samples taken while the user is genuinely there - screen
///   awake and on console - which is what makes the overnight gap form at all.
/// - **The threshold is internal.** It is never a setting, never surfaced, never
///   asked about. The whole point is that the user spends no thought on this.
/// - **First sample is never an arrival.** It seeds `lastPresence` and nothing
///   else, so a fresh install does not fire a notification seconds after launch.
public enum ArrivalLog {
    /// How long away counts as having been away.
    ///
    /// Long enough that lunch, a meeting, or an afternoon out does not read as a
    /// new day; short enough that a genuine night away always does. It is not
    /// tuned to a particular sleep schedule, because it does not need to be -
    /// the digest is about absence, not about mornings.
    public static let absenceThreshold: TimeInterval = 5 * 60 * 60

    /// How many arrivals to remember. A month of them is plenty to see a habit,
    /// and a bounded log means this can live in `UserDefaults` without ever
    /// becoming something that needs pruning.
    public static let sampleLimit = 30

    /// Below this, `learnedMorning` returns nil rather than a guess. Four
    /// mornings is not a habit, and a confident wrong answer is worse than an
    /// honest "still learning".
    public static let minimumSamplesToLearn = 5

    /// The result of folding one presence sample in. A value, so the caller
    /// persists it and the logic stays testable.
    public struct Update: Sendable, Equatable {
        public let lastPresence: Date
        public let arrivals: [Date]
        /// True only on the sample that crossed the gap - the edge, not the
        /// state. The caller acts on this exactly once per return.
        public let isArrival: Bool

        public init(lastPresence: Date, arrivals: [Date], isArrival: Bool) {
            self.lastPresence = lastPresence
            self.arrivals = arrivals
            self.isArrival = isArrival
        }
    }

    /// Fold one "the user is here right now" sample into the log.
    ///
    /// `lastPresence` is nil only before the very first sample ever taken.
    public static func observe(
        _ moment: Date,
        lastPresence: Date?,
        arrivals: [Date],
        threshold: TimeInterval = absenceThreshold,
        limit: Int = sampleLimit
    ) -> Update {
        guard let lastPresence else {
            // Seed only. See the first-sample rule above.
            return Update(lastPresence: moment, arrivals: arrivals, isArrival: false)
        }
        // A negative gap means the clock moved backwards (timezone change, NTP
        // correction, manual set). Follow the clock, but do not let it
        // manufacture an arrival out of arithmetic.
        let gap = moment.timeIntervalSince(lastPresence)
        guard gap >= threshold else {
            return Update(lastPresence: moment, arrivals: arrivals, isArrival: false)
        }
        return Update(lastPresence: moment,
                      arrivals: (arrivals + [moment]).suffix(limit).map { $0 },
                      isArrival: true)
    }

    /// The time of day the user typically comes back, or nil while still
    /// learning.
    ///
    /// Median rather than mean: one 03:00 night should not drag the estimate,
    /// and the middle element is an actual morning the user had rather than an
    /// average of mornings they did not.
    ///
    /// Known limit, accepted on purpose: this does not handle wrapping around
    /// midnight, so arrivals split between 23:50 and 00:10 would average to
    /// midday. Someone whose returns straddle midnight has no single morning to
    /// learn, and this is only used to pick an hour for a phone notification -
    /// the Mac never consults it.
    public static func learnedMorning(
        from arrivals: [Date], calendar: Calendar = .current
    ) -> DateComponents? {
        guard arrivals.count >= minimumSamplesToLearn else { return nil }
        let minutes = arrivals.map { arrival -> Int in
            let parts = calendar.dateComponents([.hour, .minute], from: arrival)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }.sorted()
        let middle = minutes[minutes.count / 2]
        return DateComponents(hour: middle / 60, minute: middle % 60)
    }

    /// The next time that hour and minute comes round, strictly after `date`.
    /// Used only by the iOS scheduler; macOS posts on arrival and never needs a
    /// future date at all.
    public static func nextOccurrence(
        of morning: DateComponents, after date: Date, calendar: Calendar = .current
    ) -> Date? {
        calendar.nextDate(after: date, matching: morning,
                          matchingPolicy: .nextTime, direction: .forward)
    }
}
