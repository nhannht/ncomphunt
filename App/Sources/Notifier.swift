#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CompHuntKit
import Foundation
import UserNotifications

enum Notifier {
    /// Retained for the lifetime of the app: `UNUserNotificationCenter.delegate`
    /// is a weak reference, and a delegate that deallocates takes foreground
    /// presentation and tap handling down with it, silently.
    private static let delegate = NotificationDelegate()

    /// Sound and badge are requested alongside alerts. Alert-only means a
    /// banner that appears silently for a few seconds and leaves no trace,
    /// which is indistinguishable from no notification at all.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = delegate
        Task {
            do {
                _ = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                FileHandle.standardError.write(
                    Data("[comphunt] notification auth failed: \(error)\n".utf8))
            }
        }
    }

    /// One-off notification, used for action outcomes (menus are transient,
    /// so filing results cannot surface inline).
    ///
    /// `key` is the competition's dedupe key: it rides along in `userInfo` so a
    /// tap can deep-link to that row.
    static func post(_ title: String, body: String = "", key: String? = nil, sound: Bool = true) {
        // The request is built INSIDE the task: `UNNotificationRequest` and its
        // content are not Sendable, so only these strings cross the boundary.
        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            if !body.isEmpty {
                content.body = body
            }
            content.sound = sound ? .default : nil
            if let key { content.userInfo[NotificationDelegate.keyField] = key }
            await submit(UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// One scheduled post, whichever planner produced it.
    ///
    /// The two paths differ in what they are ABOUT - a deadline versus a
    /// morning - not in how they are delivered, so they meet here and nowhere
    /// else. `key` is nil for a digest, which is about the whole list and has
    /// no single competition to open.
    struct Scheduled {
        let id: String
        let title: String
        let body: String
        let fireDate: Date
        let key: String?
    }

    /// Schedule deadline reminders for the marked competitions.
    static func replaceReminders(with plans: [ReminderPlan]) async {
        await replace(prefix: ReminderPlan.identifierPrefix, with: plans.map {
            Scheduled(id: $0.id, title: $0.title, body: $0.body,
                      fireDate: $0.fireDate, key: $0.key)
        })
    }

    /// Schedule the morning digests.
    static func replaceDigests(with plans: [DigestPlan]) async {
        await replace(prefix: DigestPlan.identifierPrefix, with: plans.map {
            Scheduled(id: $0.id, title: $0.title, body: $0.body,
                      fireDate: $0.fireDate, key: nil)
        })
    }

    static func cancelAllReminders() async {
        await replace(prefix: ReminderPlan.identifierPrefix, with: [])
    }

    static func cancelAllDigests() async {
        await replace(prefix: DigestPlan.identifierPrefix, with: [])
    }

    static func pendingReminderCount() async -> Int {
        await pendingCount(prefix: ReminderPlan.identifierPrefix)
    }

    static func pendingDigestCount() async -> Int {
        await pendingCount(prefix: DigestPlan.identifierPrefix)
    }

    /// When the next pending digest will fire, straight from the notification
    /// centre - the Settings row's proof that a morning post is actually
    /// queued, not just that the toggle is on.
    static func nextDigestDate() async -> Date? {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(DigestPlan.identifierPrefix) }
            .compactMap {
                ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            }
            .min()
    }

    /// Replace everything under one prefix, leaving the other prefix untouched.
    ///
    /// A full replace rather than a diff: the caller only reaches here when the
    /// desired set actually changed, and identifiers are derived from what the
    /// post is about, so re-adding an unchanged one is a no-op overwrite rather
    /// than a duplicate. Scoping by prefix is what keeps the reminder and digest
    /// paths from clearing each other.
    private static func replace(prefix: String, with items: [Scheduled]) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            if !item.body.isEmpty { content.body = item.body }
            content.sound = .default
            if let key = item.key {
                content.userInfo[NotificationDelegate.keyField] = key
            }
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            // Calendar-triggered, so the system fires it whether or not the app
            // is running. This is the whole reason these are reliable where
            // refresh-driven notifications are not.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components, repeats: false)
            await submit(UNNotificationRequest(
                identifier: item.id, content: content, trigger: trigger))
        }
    }

    private static func pendingCount(prefix: String) async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .count { $0.identifier.hasPrefix(prefix) }
    }

    private static func submit(_ request: UNNotificationRequest) async {
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            FileHandle.standardError.write(
                Data("[comphunt] notification post failed: \(error)\n".utf8))
        }
    }

    // MARK: authorization, made visible

    /// The Settings row's view of the OS permission: what to say, and whether
    /// the system settings pane is where a fix lives. The flag exists so the
    /// row can offer a button instead of spelling a settings path in prose.
    struct PermissionStatus {
        let text: String
        let fixableInSystemSettings: Bool
    }

    /// One-line, user-facing status for the Settings row.
    ///
    /// Without this a denial is completely invisible: `requestAuthorization`
    /// reports it only to a discarded return value, and `add(_:)` does not
    /// throw when unauthorized - it just never shows anything.
    static func permissionStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return settings.alertSetting == .enabled
                ? PermissionStatus(text: "Allowed", fixableInSystemSettings: false)
                : PermissionStatus(text: "Allowed, but alerts are turned off.",
                                   fixableInSystemSettings: true)
        case .denied:
            return PermissionStatus(text: "Notifications are denied.",
                                    fixableInSystemSettings: true)
        case .notDetermined:
            return PermissionStatus(text: "Not requested yet.",
                                    fixableInSystemSettings: false)
        @unknown default:
            return PermissionStatus(text: "Unknown.", fixableInSystemSettings: false)
        }
    }

    /// Jump straight to this app's notification pane, so re-granting is one
    /// click rather than a hunt through settings.
    @MainActor
    static func openSystemNotificationSettings() {
        #if os(macOS)
        // The `id` query lands on the app's own sub-pane, not the top-level
        // Notifications list.
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

/// Foreground presentation and taps.
///
/// Without a delegate, macOS and iOS discard every notification posted while
/// nCompHunt is the active app - which is exactly when someone presses Refresh
/// and watches for the result.
/// `@unchecked Sendable` is honest here rather than a waiver: the class holds
/// no stored properties at all, so there is no mutable state to race on. The
/// compiler cannot derive that through `NSObject`, which is not `Sendable`.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let keyField = "competitionKey"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let key = response.notification.request.content
            .userInfo[Self.keyField] as? String
        else { return }
        // Reuses the widget's deep-link route rather than adding a second
        // channel into the window: one path, one behaviour.
        let url = competitionDeepLink(key: key)
        await MainActor.run {
            #if os(macOS)
            _ = NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}
