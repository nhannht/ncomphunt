import CompHuntKit
import SwiftData
import SwiftUI

/// The shared action set for a competition, used by the detail header's
/// compact menu and the right-click context menu on list rows. macOS-native
/// actions lead (Calendar, Share covers Notes/Messages/Mail, Copy Link);
/// YouTrack filing is one small item at the bottom, not a headline button.
struct CompetitionActionsMenu: View {
    let competition: Competition

    var body: some View {
        if let url = URL(string: competition.url) {
            Button("Open Competition Page", systemImage: "safari") {
                NSWorkspace.shared.open(url)
            }
            ShareLink(item: url, subject: Text(competition.title)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Copy Link", systemImage: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(competition.url, forType: .string)
            }
        }
        if competition.nextRelevantDate != nil {
            Button("Add to Calendar", systemImage: "calendar.badge.plus") {
                CompetitionActions.addToCalendar(competition)
            }
        }
        Divider()
        YouTrackMenuItem(competition: competition)
    }
}

@MainActor
enum CompetitionActions {
    /// Hands the competition to Calendar as an .ics import: no EventKit
    /// permission prompt, and the user confirms inside Calendar itself.
    static func addToCalendar(_ competition: Competition) {
        guard let ics = ICSBuilder.calendar(for: competition) else { return }
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-ics", directoryHint: .isDirectory)
        let slug = competition.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(40)
        let file = dir.appending(path: "\(slug.isEmpty ? "competition" : String(slug)).ics")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try ics.write(to: file, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(file)
        } catch {
            Notifier.post("Could not create calendar event",
                          body: error.localizedDescription)
        }
    }
}

/// Small menu item that files the competition into the YouTrack COMP project,
/// then flips to a link to the issue. Hidden entirely when YouTrack is not
/// configured. Outcomes surface as notifications since menus are transient.
struct YouTrackMenuItem: View {
    let competition: Competition

    @Environment(\.modelContext) private var context

    /// Config is read from disk once per app run.
    private static let client = YouTrackClient()

    var body: some View {
        if let issueID = competition.trackedIssueID {
            if let url = Self.client?.issueURL(issueID) {
                Button("Open \(issueID) in YouTrack", systemImage: "checkmark.circle") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else if let client = Self.client {
            Button("Track in YouTrack", systemImage: "plus.circle") {
                file(with: client)
            }
        }
    }

    private func file(with client: YouTrackClient) {
        Task {
            do {
                let issueID = try await client.createIssue(
                    summary: competition.title,
                    description: Self.issueDescription(for: competition))
                competition.trackedIssueID = issueID
                try context.save()
                Notifier.post("Tracked as \(issueID)", body: competition.title)
            } catch {
                Notifier.post("YouTrack filing failed", body: String(describing: error))
            }
        }
    }

    static func issueDescription(for competition: Competition) -> String {
        var lines = [
            "Source: \(competition.source)",
            "URL: \(competition.url)",
            "Category: \(competition.category.displayName)",
            "Region: \(competition.region.displayName)",
        ]
        if !competition.location.isEmpty {
            lines.append("Location: \(competition.location)")
        }
        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        if let deadline = competition.registrationDeadline {
            lines.append("Deadline: \(deadline.formatted(dateStyle))")
        }
        if let start = competition.startDate {
            lines.append("Starts: \(start.formatted(dateStyle))")
        }
        if let end = competition.endDate {
            lines.append("Ends: \(end.formatted(dateStyle))")
        }
        if !competition.prize.isEmpty {
            lines.append("Prize: \(competition.prize)")
        }
        if !competition.details.isEmpty {
            var snippet = competition.details.trimmingCharacters(in: .whitespacesAndNewlines)
            if snippet.count > 1500 {
                snippet = String(snippet.prefix(1500)) + " [...]"
            }
            lines += ["", "## Details", "", snippet]
        }
        lines += ["", "_Filed by CompHunt._"]
        return lines.joined(separator: "\n")
    }
}
