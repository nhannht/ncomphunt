import CompHuntKit
import Foundation

/// Keeps the pending notifications reconciled with the store. The impure half
/// of `ReminderPlan` and `DigestPlan`: all shaping decisions live in the kit,
/// this only applies them - the same split as `CalendarEventPlan` and
/// `CalendarSyncService`.
///
/// Two independent paths, deliberately not merged:
///
/// ```
///   marked competitions  ->  ReminderPlan  ->  before a deadline
///   the whole list       ->  DigestPlan    ->  once each morning
/// ```
///
/// Each owns its own identifier prefix, so turning one off leaves the other
/// alone. There is no mute list any more: nothing is subscribed until it is
/// marked, so there is nothing to unsubscribe from.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private enum Key {
        static let enabled = "reminders.enabled"
        static let digestEnabled = "digest.enabled"
        static let digestHour = "digest.hour"
        static let digestMinute = "digest.minute"
    }

    /// The identifiers last handed to the notification centre, per path.
    /// Rescheduling is skipped when the desired set matches, because
    /// `recomputeMenuBar` ticks every 60 seconds and rewriting the whole set a
    /// minute would be pure waste. Same gate as the widget's `lastSnapshotKeys`.
    private var lastReminders: [String]?
    private var lastDigests: [String]?

    /// How many of each are pending, for the Settings rows.
    private(set) var scheduledCount = 0
    private(set) var scheduledDigestCount = 0

    // MARK: preferences

    /// Default on: the OS permission prompt is already the gate, and since
    /// nothing is subscribed until it is marked, "on" costs an unmarked list
    /// exactly nothing.
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.enabled) as? Bool ?? true
    }

    var isDigestEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.digestEnabled) as? Bool ?? true
    }

    /// When the digest arrives, as local hour and minute. "Morning" is
    /// personal, and one that lands after someone starts work is just a
    /// notification.
    var digestHour: Int {
        UserDefaults.standard.object(forKey: Key.digestHour) as? Int
            ?? DigestPlan.defaultHour
    }

    var digestMinute: Int {
        UserDefaults.standard.object(forKey: Key.digestMinute) as? Int
            ?? DigestPlan.defaultMinute
    }

    /// The digest time as a `Date` today, for a `DatePicker` to bind to.
    var digestTime: Date {
        Calendar.current.date(
            bySettingHour: digestHour, minute: digestMinute, second: 0, of: .now)
            ?? .now
    }

    // MARK: reconcile

    /// Recompute both sets and apply whichever changed.
    func reschedule(competitions: [Competition], now: Date = .now) async {
        await applyReminders(competitions: competitions, now: now)
        await applyDigests(competitions: competitions, now: now)
    }

    private func applyReminders(competitions: [Competition], now: Date) async {
        guard isEnabled else {
            await disableReminders()
            return
        }
        let plans = ReminderPlan.plans(for: competitions, now: now)
        let identifiers = plans.map(\.id)
        guard identifiers != lastReminders else { return }
        lastReminders = identifiers
        scheduledCount = plans.count
        await Notifier.replaceReminders(with: plans)
    }

    private func applyDigests(competitions: [Competition], now: Date) async {
        guard isDigestEnabled else {
            await disableDigests()
            return
        }
        let plans = DigestPlan.plans(
            for: competitions, hour: digestHour, minute: digestMinute, now: now)
        // Content, not just identity: a digest keeps the same id all day while
        // its counts change underneath, so comparing ids alone would pin the
        // first version of the morning's numbers.
        let signature = plans.map { "\($0.id)|\($0.title)|\($0.body)" }
        guard signature != lastDigests else { return }
        lastDigests = signature
        scheduledDigestCount = plans.count
        await Notifier.replaceDigests(with: plans)
    }

    /// Flip deadline reminders off or on. Off clears the pending set
    /// immediately rather than letting already-scheduled ones keep firing.
    func setEnabled(_ on: Bool, competitions: [Competition]) async {
        UserDefaults.standard.set(on, forKey: Key.enabled)
        if on {
            // Force the next pass through: the desired set may be identical to
            // what was applied before it was switched off.
            lastReminders = nil
            await applyReminders(competitions: competitions, now: .now)
        } else {
            await disableReminders()
        }
    }

    func setDigestEnabled(_ on: Bool, competitions: [Competition]) async {
        UserDefaults.standard.set(on, forKey: Key.digestEnabled)
        if on {
            lastDigests = nil
            await applyDigests(competitions: competitions, now: .now)
        } else {
            await disableDigests()
        }
    }

    func setDigestTime(_ time: Date, competitions: [Competition]) async {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        UserDefaults.standard.set(parts.hour ?? DigestPlan.defaultHour,
                                  forKey: Key.digestHour)
        UserDefaults.standard.set(parts.minute ?? DigestPlan.defaultMinute,
                                  forKey: Key.digestMinute)
        lastDigests = nil
        await applyDigests(competitions: competitions, now: .now)
    }

    private func disableReminders() async {
        await Notifier.cancelAllReminders()
        lastReminders = []
        scheduledCount = 0
    }

    private func disableDigests() async {
        await Notifier.cancelAllDigests()
        lastDigests = []
        scheduledDigestCount = 0
    }

    /// Read the true pending counts back from the notification centre, for the
    /// Settings rows on a fresh launch when nothing has been rescheduled yet.
    func refreshScheduledCount() async {
        scheduledCount = await Notifier.pendingReminderCount()
        scheduledDigestCount = await Notifier.pendingDigestCount()
    }
}
