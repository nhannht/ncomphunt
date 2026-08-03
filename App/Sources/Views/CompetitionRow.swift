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

// `whenLine` moved to CompHuntKit (Schedule.swift): the When column now
// sorts by the same date the phrase shows, and one derivation for both
// lives where it is unit-testable.
