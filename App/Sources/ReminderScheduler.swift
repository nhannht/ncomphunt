import CompHuntKit
import Foundation

/// Keeps the pending deadline reminders reconciled with the store, and owns the
/// mute set. The impure half of `ReminderPlan`: all shaping decisions live in
/// the kit, this only applies them - the same split as `CalendarEventPlan` and
/// `CalendarSyncService`.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private enum Key {
        static let enabled = "reminders.enabled"
        static let muted = "reminders.muted"
    }

    /// The identifiers last handed to the notification centre. Rescheduling is
    /// skipped when the desired set matches, because `recomputeMenuBar` ticks
    /// every 60 seconds and rewriting 48 notifications a minute would be pure
    /// waste. Same gate as the widget's `lastSnapshotKeys`.
    private var lastApplied: [String]?

    /// How many reminders are currently pending, for the Settings row. A
    /// truncated schedule must never read as a complete one.
    private(set) var scheduledCount = 0

    // MARK: preferences

    /// Default on: the OS permission prompt is already the gate, so a second
    /// opt-in would just mean nobody ever gets the feature.
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.enabled) as? Bool ?? true
    }

    var muted: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Key.muted) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Key.muted) }
    }

    func isMuted(_ competition: Competition) -> Bool {
        muted.contains(competition.key)
    }

    // MARK: reconcile

    /// Recompute the reminder window and apply it if it changed.
    func reschedule(competitions: [Competition], now: Date = .now) async {
        guard isEnabled else {
            await disableAll()
            return
        }
        let plans = ReminderPlan.plans(for: competitions, muted: muted, now: now)
        let identifiers = plans.map(\.id)
        guard identifiers != lastApplied else { return }
        lastApplied = identifiers
        scheduledCount = plans.count
        await Notifier.replaceReminders(with: plans)
    }

    /// Flip reminders off or on. Turning them off clears the pending set
    /// immediately rather than letting already-scheduled ones keep firing.
    func setEnabled(_ on: Bool, competitions: [Competition]) async {
        UserDefaults.standard.set(on, forKey: Key.enabled)
        if on {
            // Force the next reschedule through: the desired set may be
            // identical to what was applied before it was switched off.
            lastApplied = nil
            await reschedule(competitions: competitions)
        } else {
            await disableAll()
        }
    }

    /// Mute or unmute one competition, then re-derive the window so a freed
    /// slot is refilled by the next competition in line.
    func setMuted(_ isMuted: Bool, key: String, competitions: [Competition]) async {
        var updated = muted
        if isMuted { updated.insert(key) } else { updated.remove(key) }
        muted = updated
        await reschedule(competitions: competitions)
    }

    private func disableAll() async {
        await Notifier.cancelAllReminders()
        lastApplied = []
        scheduledCount = 0
    }

    /// Read the true pending count back from the notification centre, for the
    /// Settings row on a fresh launch when nothing has been rescheduled yet.
    func refreshScheduledCount() async {
        scheduledCount = await Notifier.pendingReminderCount()
    }
}
