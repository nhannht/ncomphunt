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
///   the whole list       ->  DigestPlan    ->  once, when you come back
/// ```
///
/// The two halves reach the user differently because the platforms differ.
/// macOS is always running, so it watches for the user returning (`Presence`)
/// and posts the digest right then - nothing is ever scheduled, so nothing can
/// fall due while the Mac is asleep. iOS is not running and cannot observe a
/// return, so it schedules at the hour `ArrivalLog` learned from the returns it
/// did see. Neither platform asks the user to pick a time.
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
        static let digestPostedAt = "digest.postedAt"
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
    /// When the next digest fires, for the same rows - nil when the horizon
    /// is quiet or digests are off.
    private(set) var nextDigestDate: Date?

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

    /// When the last digest actually went out.
    ///
    /// One stored `Date` answers both questions the app has: "was one already
    /// sent today", by comparing its day, and "when was the last one", for the
    /// Settings row. There is no stored hour because there is no chosen hour.
    var lastDigestPostedAt: Date? {
        get { UserDefaults.standard.object(forKey: Key.digestPostedAt) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Key.digestPostedAt) }
    }

    // MARK: reconcile

    /// Recompute both sets and apply whichever changed.
    ///
    /// Only reminders are scheduled on macOS. The digest there is posted on
    /// arrival by `noteArrival`, so there is nothing pending for a refresh to
    /// reconcile.
    func reschedule(competitions: [Competition], now: Date = .now) async {
        await applyReminders(competitions: competitions, now: now)
        #if os(iOS)
        await applyDigests(competitions: competitions, now: now)
        #else
        // Upgrade path. Builds before COMP-49 scheduled macOS digests at a
        // wall-clock hour, and those pending requests survive an app update -
        // they would keep firing at 08:00 alongside the new arrival posts.
        // `lastDigests` starts nil each launch, so this clears them once.
        if lastDigests == nil {
            lastDigests = []
            await Notifier.cancelAllDigests()
        }
        #endif
    }

    #if os(macOS)
    /// The user just came back to the machine. Post the summary now.
    ///
    /// Immediate, not scheduled: a scheduled post is exactly what failed before,
    /// because the fire instant kept landing while the Mac was asleep. Posting at
    /// the moment they return means the machine is by definition awake and the
    /// person is by definition there.
    ///
    /// At most one a day. `DigestPlan.identifier` is already day-keyed, so
    /// comparing it against the last post's day needs no extra state.
    func noteArrival(competitions: [Competition], now: Date = .now) {
        guard isDigestEnabled else { return }
        guard let plan = DigestPlan.make(for: competitions, at: now) else { return }
        if let last = lastDigestPostedAt,
           DigestPlan.identifier(for: last, calendar: .current) == plan.id { return }
        lastDigestPostedAt = now
        Notifier.post(plan.title, body: plan.body)
    }
    #endif

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

    #if os(iOS)
    /// Schedule the next digest at the hour learned from observed returns.
    ///
    /// Nothing is queued until there is a habit to read - `learnedMorning` is
    /// nil below its sample floor - and nothing is queued for a quiet horizon.
    /// Both are honest empties that Settings reports as such.
    private func applyDigests(competitions: [Competition], now: Date) async {
        guard isDigestEnabled,
              let morning = Presence.learnedMorning,
              let fireDate = ArrivalLog.nextOccurrence(of: morning, after: now),
              let plan = DigestPlan.make(for: competitions, at: fireDate)
        else {
            await disableDigests()
            return
        }
        // Content, not just identity: a digest keeps the same id all day while
        // its counts change underneath, so comparing ids alone would pin the
        // first version of that morning's numbers.
        let signature = ["\(plan.id)|\(plan.title)|\(plan.body)"]
        guard signature != lastDigests else { return }
        lastDigests = signature
        scheduledDigestCount = 1
        nextDigestDate = plan.fireDate
        await Notifier.replaceDigests(with: [plan])
    }
    #endif

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

    /// Flip the daily summary off or on. A whole-feature switch is a decision,
    /// not a configuration - it is the one thing about the digest the user is
    /// still asked.
    func setDigestEnabled(_ on: Bool, competitions: [Competition]) async {
        UserDefaults.standard.set(on, forKey: Key.digestEnabled)
        #if os(iOS)
        if on {
            lastDigests = nil
            await applyDigests(competitions: competitions, now: .now)
        } else {
            await disableDigests()
        }
        #endif
    }

    private func disableReminders() async {
        await Notifier.cancelAllReminders()
        lastReminders = []
        scheduledCount = 0
    }

    #if os(iOS)
    private func disableDigests() async {
        await Notifier.cancelAllDigests()
        lastDigests = []
        scheduledDigestCount = 0
        nextDigestDate = nil
    }
    #endif

    /// Read the true pending counts back from the notification centre, for the
    /// Settings rows on a fresh launch when nothing has been rescheduled yet.
    func refreshScheduledCount() async {
        scheduledCount = await Notifier.pendingReminderCount()
        scheduledDigestCount = await Notifier.pendingDigestCount()
        nextDigestDate = await Notifier.nextDigestDate()
    }
}
