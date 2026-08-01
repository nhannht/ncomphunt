#if os(macOS)
import CompHuntKit
import SwiftUI

/// The right-hand pane of the desktop split, and the table style's inspector:
/// the full record for the selected competition. The content column is capped
/// and centered so an ultra-wide pane reads as an intentional card rather
/// than a strip cramped against the divider.
struct CompetitionDetailPane: View {
    let competition: Competition?

    var body: some View {
        if let competition {
            detail(competition)
        } else {
            ContentUnavailableView(
                "Select a competition",
                systemImage: "trophy",
                description: Text("Details appear here."))
        }
    }

    private func detail(_ competition: Competition) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(competition.title)
                            .font(.title2.bold())
                            .textSelection(.enabled)
                        Spacer()
                        // Out of the actions menu and onto the surface: marking
                        // is the thing people came here to do, and two clicks
                        // behind an ellipsis is where features go to be unused.
                        MarkButton(competition: competition)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .font(.title3)
                            .foregroundStyle(competition.isMarked ? .yellow : .secondary)
                        Menu {
                            CompetitionActionsMenu(competition: competition)
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    HStack(spacing: 6) {
                        CategoryDot(competition.category)
                        Text(competition.category.shortLabel)
                            .foregroundStyle(competition.category.tint)
                        if competition.region == .vietnam {
                            Text("Vietnam").foregroundStyle(.red)
                        }
                        Text("via \(competition.source)")
                            .foregroundStyle(.secondary)
                        if let issueID = competition.trackedIssueID {
                            Text("tracked \(issueID)")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                }

                // Only once marked. An unmarked competition has no pipeline to
                // be in, and showing an empty one on every row would be noise.
                if competition.isMarked {
                    StatusPicker(competition: competition)
                        .pickerStyle(.segmented)
                        .labelsHidden()
                }

                if let url = URL(string: competition.url) {
                    Link(destination: url) {
                        Label("Open competition page", systemImage: "safari")
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    if !competition.organizer.isEmpty {
                        detailRow("Organizer", competition.organizer)
                    }
                    if !competition.location.isEmpty {
                        detailRow("Location", competition.location)
                    }
                    if let deadline = competition.registrationDeadline {
                        detailRow("Deadline", deadline.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let start = competition.startDate {
                        detailRow("Starts", start.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let end = competition.endDate {
                        detailRow("Ends", end.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !competition.prize.isEmpty {
                        detailRow("Prize", competition.prize)
                    }
                    detailRow("First seen", competition.firstSeen.formatted(date: .abbreviated, time: .shortened))
                }

                if !competition.details.isEmpty {
                    Divider()
                    Text(competition.details)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
#endif
