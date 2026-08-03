import CompHuntKit
import SwiftUI

struct CompetitionRow: View {
    let competition: Competition

    /// A finished competition still appears when it answers a search, so the
    /// row has to say so unmistakably. Greyed AND labelled, not one or the
    /// other: colour alone is not a message everyone can read. The label is
    /// the whenLine's "ended ..." text plus the Ended section header.
    private var hasEnded: Bool { !competition.isCurrent() }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            StatusIndicator(status: competition.status)
                .padding(.top, 2)
            CategoryDot(competition.category)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(competition.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if !hasEnded, competition.isNew() {
                        Text("new")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
                HStack(spacing: 4) {
                    // Every tag, not just the leading one. The identity dot on
                    // the left stays single - the lead tag IS the row's colour -
                    // but hiding the rest until the detail pane made the whole
                    // feature undiscoverable in the surface people scan.
                    ForEach(competition.shownCategoryTags, id: \.self) { tag in
                        Text(tag.shortLabel)
                            .foregroundStyle(tag.tint)
                    }
                    if competition.region == .vietnam {
                        Text("VN")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
            }
            Spacer(minLength: 12)
            // Mail-style trailing meta: the date and prize hug the row's right
            // edge, so the space between title and date reads as layout, not
            // as a void trailing every line.
            VStack(alignment: .trailing, spacing: 1) {
                Text(competition.whenLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !competition.prize.isEmpty {
                    Text(competition.prize)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .padding(.top, 3)
        }
        .padding(.vertical, 1)
        .opacity(hasEnded ? 0.55 : 1)
    }
}

extension Competition {
    /// One relative phrase for "when does this matter": the deadline first,
    /// then start, then end - or when it closed, for a finished competition.
    /// Shared by the list row and the table's When column so the two styles
    /// can never phrase the same date differently.
    var whenLine: String {
        let now = Date.now
        if !isCurrent(asOf: now) {
            // Say when it closed rather than falling through to the source
            // name, which reads as though the row simply has no dates.
            if let end = endDate {
                return "ended \(end.formatted(.relative(presentation: .named)))"
            }
            if let deadline = registrationDeadline {
                return "closed \(deadline.formatted(.relative(presentation: .named)))"
            }
            return source
        }
        if let deadline = registrationDeadline {
            return "due \(deadline.formatted(.relative(presentation: .named)))"
        }
        if let start = startDate, start > now {
            return "starts \(start.formatted(.relative(presentation: .named)))"
        }
        if let end = endDate, end > now {
            return "ends \(end.formatted(.relative(presentation: .named)))"
        }
        return source
    }
}
