import CompHuntKit
import SwiftUI

/// The category filter, shrunk from a sidebar column to one row of chips.
///
/// Idle categories are icon-only so all eleven filters fit an iPhone width
/// without the invisible horizontal scroll; the selected one morphs into a
/// labeled capsule tinted with its category color, so the icon language never
/// has to be memorized - the chosen chip names itself. The icons are the macOS
/// sidebar's `systemImage` set: one iconography on both platforms, and color
/// appears only on the selection instead of ten permanent dots.
///
/// Like the sidebar it replaced, this owns no state: chips write into the
/// query string through the binding and read their highlight back out of it,
/// so the chip row and the list can never disagree.
struct CategoryChipRow: View {
    @Binding var selection: CompetitionFilter?
    /// A second axis, not a sixth category: "things I marked" cuts across every
    /// category rather than being one of them. Divided off so the row does not
    /// read as one list of mutually exclusive choices.
    @Binding var markedOnly: Bool

    @Namespace private var morph

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                markedChip
                Divider().frame(height: 14).padding(.horizontal, 4)
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
            withAnimation(Motion.state) { markedOnly.toggle() }
        } label: {
            Image(systemName: markedOnly ? "star.fill" : "star")
                .font(.caption)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(markedOnly ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
        .accessibilityLabel("Marked only")
        .help("Show only competitions you marked")
    }

    private func chip(_ filter: CompetitionFilter) -> some View {
        let isSelected = (selection ?? .all) == filter
        let tint = filter.categoryValue?.tint
        return Button {
            withAnimation(Motion.state) { selection = filter }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.systemImage)
                    .font(.caption)
                if isSelected {
                    Text(filter.categoryValue?.shortLabel ?? "All")
                        .font(.caption.weight(.medium))
                }
            }
            .padding(.horizontal, isSelected ? 10 : 6)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(tint.map { AnyShapeStyle($0.opacity(0.16)) }
                            ?? AnyShapeStyle(.quaternary))
                        .matchedGeometryEffect(id: "selection", in: morph)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected
            ? (tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
            : AnyShapeStyle(.secondary))
        .accessibilityLabel(filter.label)
    }
}
