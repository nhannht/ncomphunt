import CompHuntKit
import SwiftUI

/// The category filter as a desktop sidebar column.
///
/// It owns no state, exactly like the chip row it replaces on macOS: rows write
/// into the query string through the binding and read their highlight back out
/// of it, so the sidebar and the list can never disagree.
///
/// Colour carries the category here, not a glyph. A column of ten SF Symbols
/// reads as ten unrelated pictures, and half of them are arbitrary anyway - a
/// hammer for a hackathon, a camera for media - so the icon has to be learned
/// per row and never becomes scannable. The dot is the marker the list rows,
/// the expanded record and the widget already use, so the sidebar teaches the
/// colour that every other surface then relies on.
struct CategorySidebar: View {
    @Binding var selection: CompetitionFilter?
    @Binding var markedOnly: Bool

    var body: some View {
        List(selection: highlighted) {
            Section {
                markedRow
            }
            // "Kind" rather than "Category": the sidebar answers what a
            // competition IS, and the region filter in the toolbar answers
            // where. Two axes, never one list.
            Section("Kind") {
                ForEach(CompetitionFilter.allCases) { filter in
                    row(filter).tag(filter)
                }
            }
        }
    }

    /// `nil` in the query means "every category", which List would draw as no
    /// row highlighted at all. Mapping it onto `.all` keeps exactly one row lit
    /// without giving the query a second way to say the same thing.
    private var highlighted: Binding<CompetitionFilter?> {
        Binding(
            get: { selection ?? .all },
            set: { selection = $0 ?? .all })
    }

    /// A second axis, not an eleventh kind: "things I marked" cuts across every
    /// category rather than being one of them, so it sits in its own section
    /// above the list instead of joining it.
    private var markedRow: some View {
        Button {
            markedOnly.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: markedOnly ? "star.fill" : "star")
                    .foregroundStyle(markedOnly ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
                    .frame(width: 10)
                Text("Marked")
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(markedOnly ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .help("Show only competitions you marked")
    }

    private func row(_ filter: CompetitionFilter) -> some View {
        HStack(spacing: 8) {
            // "All" has no category and so no colour. A clear dot of the same
            // size holds the column, so its label lines up with every other
            // one rather than sitting alone against the edge.
            if let category = filter.categoryValue {
                CategoryDot(category, size: 10)
            } else {
                CategoryDot(color: .clear, size: 10)
            }
            Text(filter.label)
        }
    }
}
