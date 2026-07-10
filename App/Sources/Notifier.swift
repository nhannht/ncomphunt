import Foundation
import UserNotifications

enum Notifier {
    static func requestAuthorization() {
        Task {
            do {
                _ = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert])
            } catch {
                FileHandle.standardError.write(
                    Data("[comphunt] notification auth failed: \(error)\n".utf8))
            }
        }
    }

    static func postNewCompetitions(_ titles: [String]) {
        let title = titles.count == 1
            ? "New competition found"
            : "\(titles.count) new competitions found"
        post(title, body: titles.prefix(3).joined(separator: "\n"))
    }

    /// One-off notification, used for action outcomes (menus are transient,
    /// so filing results cannot surface inline).
    static func post(_ title: String, body: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty {
            content.body = body
        }
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                FileHandle.standardError.write(
                    Data("[comphunt] notification post failed: \(error)\n".utf8))
            }
        }
    }
}
