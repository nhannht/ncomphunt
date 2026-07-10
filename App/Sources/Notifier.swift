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
        let content = UNMutableNotificationContent()
        content.title = titles.count == 1
            ? "New competition found"
            : "\(titles.count) new competitions found"
        content.body = titles.prefix(3).joined(separator: "\n")
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
