import CompHuntKit
import SwiftUI

/// A resolved filter, shown as removable chips.
///
/// Whatever produced the query - a sentence, or eventually anything else - the
/// result is never presented as an opaque outcome. Every axis it decided on is
/// visible here and can be taken back off individually, so a filter that read
/// the request wrong is corrected in one click rather than retyped.
///
/// Generic on purpose: this renders a `CompetitionQuery` and knows nothing
/// about what produced it.
struct QueryChips: View {
    let query: CompetitionQuery
    /// Receives the query with one axis removed. An empty result means the
    /// person cleared the last chip.
    let onChange: (CompetitionQuery) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                // Fixed taxonomy order rather than Set order, so the chips do
                // not reshuffle between renders of the same query.
                ForEach(CompetitionCategory.allCases.filter(query.categories.contains), id: \.self) { category in
                    chip(category.displayName, systemImage: "tag") {
                        var updated = query
                        updated.categories.remove(category)
                        onChange(updated)
                    }
                }

                if let region = query.region {
                    chip(region.displayName, systemImage: "globe") {
                        var updated = query
                        updated.region = nil
                        onChange(updated)
                    }
                }

                ForEach(query.terms, id: \.self) { term in
                    chip(term, systemImage: "magnifyingglass") {
                        var updated = query
                        updated.terms.removeAll { $0 == term }
                        onChange(updated)
                    }
                }

                if let deadlineLabel {
                    chip(deadlineLabel, systemImage: "calendar") {
                        var updated = query
                        updated.deadlineAfter = nil
                        updated.deadlineBefore = nil
                        onChange(updated)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
    }

    /// The window is one chip, not two: it was one idea in the request and
    /// removing half of it would leave a filter nobody asked for.
    private var deadlineLabel: String? {
        guard let before = query.deadlineBefore else {
            guard let after = query.deadlineAfter else { return nil }
            return "after \(after.formatted(date: .abbreviated, time: .omitted))"
        }
        return "by \(before.formatted(date: .abbreviated, time: .omitted))"
    }

    private func chip(
        _ label: String, systemImage: String, remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(label)
                .lineLimit(1)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(label) filter")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}
