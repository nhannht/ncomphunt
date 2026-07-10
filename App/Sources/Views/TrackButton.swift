import CompHuntKit
import SwiftData
import SwiftUI

/// Files the competition into the YouTrack COMP project when the user decides
/// to enter it. One issue per competition; the id persists on the row and the
/// button becomes a link to the issue.
struct TrackButton: View {
    let competition: Competition

    @Environment(\.modelContext) private var context
    @State private var isFiling = false
    @State private var errorMessage: String?

    /// Config is read from disk once per app run.
    private static let client = YouTrackClient()

    var body: some View {
        if let issueID = competition.trackedIssueID {
            if let url = Self.client?.issueURL(issueID) {
                Link(destination: url) {
                    Label("Open \(issueID) in YouTrack", systemImage: "checkmark.circle.fill")
                }
            } else {
                Label("Tracked as \(issueID)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        } else if let client = Self.client {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    file(with: client)
                } label: {
                    if isFiling {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Track in YouTrack", systemImage: "plus.circle")
                    }
                }
                .disabled(isFiling)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        } else {
            Label("YouTrack not configured (~/.claude.json)", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private func file(with client: YouTrackClient) {
        isFiling = true
        errorMessage = nil
        Task {
            do {
                let issueID = try await client.createIssue(
                    summary: competition.title,
                    description: Self.issueDescription(for: competition))
                competition.trackedIssueID = issueID
                try context.save()
            } catch {
                errorMessage = String(describing: error)
            }
            isFiling = false
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
