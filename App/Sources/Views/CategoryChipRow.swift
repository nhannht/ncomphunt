import CompHuntKit
import SwiftUI

/// The category filter, shrunk from a sidebar column to one row of chips.
///
/// Like the sidebar it replaced, this owns no state: chips write into the
/// query string through the binding and read their highlight back out of it,
/// so the chip row and the list can never disagree.
struct CategoryChipRow: View {
    @Binding var selection: CompetitionFilter?
    /// A second axis, not a sixth category: "things I marked" cuts across every
    /// category rather than being one of them. Divided off so the row does not
    /// read as one list of six mutually exclusive choices.
    @Binding var markedOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                markedChip
                Divider().frame(height: 14)
                ForEach(CompetitionFilter.allCases) { filter in
                    chip(filter)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var markedChip: some View {
        Button {
            markedOnly.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: markedOnly ? "star.fill" : "star")
                Text("Marked")
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                markedOnly ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(markedOnly ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
        .help("Show only competitions you marked")
    }

    private func chip(_ filter: CompetitionFilter) -> some View {
        let isSelected = (selection ?? .all) == filter
        return Button {
            selection = filter
        } label: {
            HStack(spacing: 4) {
                if let category = filter.categoryValue {
                    CategoryDot(category)
                }
                Text(filter.categoryValue?.shortLabel ?? "All")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
    }
}
