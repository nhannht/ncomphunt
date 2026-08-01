import CompHuntKit
import SwiftUI

/// One tap to mark, and a picker to move it along. Both write through
/// `AppModel` rather than the model context directly, so a status change and
/// the reminder reschedule it triggers can never drift apart.
///
/// The star sets `.interested` because that is where nearly everything starts,
/// and starring is the action people reach for before they have decided
/// anything more specific. Pressing it again unmarks entirely - a star that
/// only ever turned on would be a trap.
struct MarkButton: View {
    let competition: Competition

    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.setStatus(competition.isMarked ? nil : .interested, for: competition)
        } label: {
            Label(competition.isMarked ? "Unmark" : "Mark",
                  systemImage: competition.isMarked ? "star.fill" : "star")
        }
        .help(competition.isMarked
            ? "Remove your mark and its deadline reminders"
            : "Mark this and get reminded before its deadline")
    }
}

/// The pipeline picker. Used inside the actions menu and inline in the detail
/// surfaces; the selection IS the stored status, so there is no second state to
/// disagree with what the row shows.
struct StatusPicker: View {
    let competition: Competition

    @Environment(AppModel.self) private var model

    var body: some View {
        Picker("Status", selection: Binding(
            get: { competition.status },
            set: { model.setStatus($0, for: competition) })
        ) {
            Text("Not marked").tag(CompetitionStatus?.none)
            ForEach(CompetitionStatus.allCases, id: \.self) { status in
                Label(status.displayName, systemImage: status.systemImage)
                    .tag(CompetitionStatus?.some(status))
            }
        }
    }
}

/// The row's mark, read-only. A fixed-width gutter whether or not anything is
/// in it, so marking a competition never shifts the rows around it.
struct StatusIndicator: View {
    let status: CompetitionStatus?

    /// Wide enough for the widest glyph in the set, narrow enough that an
    /// all-unmarked list does not look indented.
    static let gutterWidth: CGFloat = 13

    var body: some View {
        Group {
            if let status {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.tint)
                    .help(status.displayName)
            }
        }
        .font(.caption2)
        .frame(width: Self.gutterWidth, alignment: .leading)
    }
}

extension CompetitionStatus {
    /// Kept beside the view rather than in the kit's `CategoryStyle`, because
    /// these colours say "where this sits with me", not "what kind of thing it
    /// is", and mixing the two palettes in one file invites reusing a category
    /// tint for a status.
    var tint: Color {
        switch self {
        case .interested: .yellow
        case .applied: .blue
        case .joined: .green
        case .done: .secondary
        case .dropped: .secondary
        }
    }
}
