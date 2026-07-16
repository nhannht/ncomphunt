import CompHuntKit
import EventKit
import Foundation

/// Owns the dedicated "nCompHunt" EventKit calendar and keeps it reconciled with
/// the competition store, so a contest whose date moves updates in place instead
/// of leaving a stale one-off `.ics` import. Native by construction: no website,
/// browser extension, or bot can offer a live system calendar.
///
/// The sandboxed app needs both the `NSCalendarsFullAccessUsageDescription`
/// string and the `com.apple.security.personal-information.calendars`
/// entitlement. Full (not write-only) access is required because reconcile
/// reads, updates, and deletes its own events, which write-only access forbids.
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()
    private let calendarTitle = "nCompHunt"

    private enum Key {
        static let enabled = "calendar.syncEnabled"
        static let calendarID = "calendar.identifier"
        static let eventMap = "calendar.eventMap"   // [competitionKey: eventIdentifier]
    }

    // MARK: state

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Key.enabled) }

    private var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// One-line, user-facing status for the Settings row.
    var statusText: String {
        switch authorization {
        case .fullAccess:
            return isEnabled ? "Syncing deadlines to the nCompHunt calendar" : "Off"
        case .writeOnly:
            return "Limited access granted; full access is needed. Enable it in System Settings > Privacy & Security > Calendars."
        case .denied, .restricted:
            return "Calendar access denied. Enable it in System Settings > Privacy & Security > Calendars."
        case .notDetermined:
            return "Off"
        @unknown default:
            return "Off"
        }
    }

    // MARK: opt-in

    /// Flip sync on: request full access, and on grant enable + run an immediate
    /// reconcile. Returns whether sync is now on (false when access was denied).
    func enable(with competitions: [Competition]) async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else {
            UserDefaults.standard.set(false, forKey: Key.enabled)
            return false
        }
        UserDefaults.standard.set(true, forKey: Key.enabled)
        await sync(competitions: competitions)
        return true
    }

    /// Flip sync off. Non-destructive: the calendar and its events remain until
    /// the user explicitly removes them via `removeCalendar()`.
    func disable() {
        UserDefaults.standard.set(false, forKey: Key.enabled)
    }

    // MARK: reconcile

    /// Reconcile after a refresh. No-op when disabled or unauthorized, so users
    /// who never opt in pay nothing.
    func syncIfEnabled(competitions: [Competition]) async {
        guard isEnabled, authorization == .fullAccess else { return }
        await sync(competitions: competitions)
    }

    private func sync(competitions: [Competition], now: Date = .now) async {
        guard let calendar = ensureCalendar() else {
            Notifier.post("Calendar sync unavailable",
                          body: "Could not create the nCompHunt calendar.")
            return
        }

        let desired = competitions
            .filter { $0.isCurrent(asOf: now) }
            .compactMap { CalendarEventPlan.plan(for: $0, now: now) }

        var map = eventMap
        let diff = CalendarSyncDiff.compute(desired: desired, existingKeys: Set(map.keys))

        // Deletes: drop the event, forget the key.
        for key in diff.toDelete {
            if let id = map[key], let event = store.event(withIdentifier: id) {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
            map[key] = nil
        }

        // Events created this pass. Their identifiers are only valid after the
        // commit below, so harvest them afterwards.
        var pending: [(key: String, event: EKEvent)] = []

        // Updates: refresh in place, or recreate if the stored identifier went
        // stale (user deleted the event, or it moved out of our calendar).
        for plan in diff.toUpdate {
            if let id = map[plan.key],
               let event = store.event(withIdentifier: id),
               event.calendar == calendar {
                apply(plan, to: event)
                try? store.save(event, span: .thisEvent, commit: false)
            } else {
                pending.append((plan.key, makeEvent(plan, in: calendar)))
            }
        }

        // Creates.
        for plan in diff.toCreate {
            pending.append((plan.key, makeEvent(plan, in: calendar)))
        }

        do {
            try store.commit()
        } catch {
            Notifier.post("Calendar sync failed", body: error.localizedDescription)
            return
        }

        for (key, event) in pending {
            map[key] = event.eventIdentifier
        }
        eventMap = map
    }

    private func makeEvent(_ plan: CalendarEventPlan, in calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        apply(plan, to: event)
        try? store.save(event, span: .thisEvent, commit: false)
        return event
    }

    private func apply(_ plan: CalendarEventPlan, to event: EKEvent) {
        event.title = plan.title
        event.startDate = plan.start
        event.endDate = plan.end
        event.notes = plan.notes
        event.url = URL(string: plan.url)
        event.location = plan.location.isEmpty ? nil : plan.location
        event.alarms = [EKAlarm(relativeOffset: plan.alarmOffset)]
    }

    // MARK: calendar lifecycle

    /// The dedicated calendar, created on first use in the user's default source
    /// (usually iCloud, so events reach their other Apple devices), falling back
    /// to a local source, then any writable source. Persists its identifier.
    private func ensureCalendar() -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: Key.calendarID),
           let existing = store.calendar(withIdentifier: id) {
            return existing
        }

        // The stored identifier is lost when prefs move into the sandbox
        // container on this build's first launch, so adopt a calendar we
        // created before rather than creating a duplicate of it.
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == calendarTitle }) {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: Key.calendarID)
            return existing
        }

        var attempts: [EKSource] = []
        if let preferred = store.defaultCalendarForNewEvents?.source {
            attempts.append(preferred)
        }
        if let local = store.sources.first(where: { $0.sourceType == .local }) {
            attempts.append(local)
        }
        attempts.append(contentsOf: store.sources)

        var seen = Set<String>()
        for source in attempts where seen.insert(source.sourceIdentifier).inserted {
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = calendarTitle
            calendar.source = source
            // The nCompHunt accent blue (#3574F0), so the calendar reads as ours.
            calendar.cgColor = CGColor(srgbRed: 0.208, green: 0.455, blue: 0.941, alpha: 1)
            do {
                try store.saveCalendar(calendar, commit: true)
                UserDefaults.standard.set(calendar.calendarIdentifier, forKey: Key.calendarID)
                return calendar
            } catch {
                continue
            }
        }
        return nil
    }

    /// Explicit teardown for the Settings "Remove nCompHunt calendar" button:
    /// delete the calendar (and every event in it) and forget all local mapping.
    func removeCalendar() {
        if let id = UserDefaults.standard.string(forKey: Key.calendarID),
           let calendar = store.calendar(withIdentifier: id) {
            try? store.removeCalendar(calendar, commit: true)
        }
        UserDefaults.standard.removeObject(forKey: Key.calendarID)
        UserDefaults.standard.removeObject(forKey: Key.eventMap)
    }

    // MARK: map persistence

    private var eventMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Key.eventMap) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Key.eventMap) }
    }
}
