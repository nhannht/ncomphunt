#if os(macOS)
import CompHuntKit
import SwiftData
import SwiftUI

/// Full-width sortable table for the desktop "Table" style: the same
/// filtered and ranked rows as the list, spread across columns so a wide
/// window carries information instead of blank space.
///
/// Header clicks are not a second sort truth. The `sortOrder` binding is
/// derived from the same `ListSort` value the toolbar Sort picker uses and
/// writes back into it, so the two controls can never disagree - and the
/// actual reordering happens upstream in the query pipeline, exactly as it
/// does for the list.
struct CompetitionTablePane: View {
    let rows: [Competition]
    @Binding var selectedID: PersistentIdentifier?
    @Binding var sort: ListSort
    /// Whether the current sort runs opposite its canonical direction -
    /// toggled by re-clicking the sorted column's header, reset by MainWindow
    /// whenever the sort itself changes.
    @Binding var flipped: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        Table(rows, selection: singleSelection, sortOrder: sortOrder) {
            TableColumn("Title", sortUsing: Self.comparator(for: .title)) { competition in
                cell(competition) {
                    HStack(spacing: 6) {
                        CategoryDot(competition.category)
                        Text(competition.title)
                            .lineLimit(1)
                        if competition.isCurrent(), competition.isNew() {
                            Text("new")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            TableColumn("Category") { competition in
                cell(competition) {
                    HStack(spacing: 4) {
                        // Same full tag set as the list row; sorting still
                        // uses the single leading category.
                        ForEach(competition.shownCategoryTags, id: \.self) { tag in
                            Text(tag.shortLabel)
                                .foregroundStyle(tag.tint)
                        }
                        if competition.region == .vietnam {
                            Text("VN").foregroundStyle(.red)
                        }
                    }
                }
            }
            .width(min: 50, ideal: 70)
            TableColumn("When", sortUsing: Self.comparator(for: .deadline)) { competition in
                cell(competition) {
                    Text(competition.whenLine)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 100, ideal: 150)
            TableColumn("Prize", sortUsing: Self.comparator(for: .prize)) { competition in
                cell(competition) {
                    // The normalized USD when the parser priced the row -
                    // that is what the column sorts by - else the raw string.
                    Text(competition.prizeValue.compactUSD ?? competition.prize)
                        .foregroundStyle(.green)
                }
            }
            .width(min: 70, ideal: 110)
            TableColumn("Fit", sortUsing: Self.comparator(for: .fit)) { competition in
                cell(competition) {
                    // The number alone; the headline and reasons live in the
                    // inspector, where there is room to say why.
                    Text("\(competition.fitValue.score)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .width(min: 34, ideal: 44)
            TableColumn("Source", sortUsing: Self.comparator(for: .source)) { competition in
                cell(competition) {
                    Text(SourceID(rawValue: competition.source)?.displayName
                        ?? competition.source)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 80, ideal: 120)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let competition = competition(for: ids.first) {
                CompetitionActionsMenu(competition: competition)
            }
        } primaryAction: { ids in
            // Double-click goes straight to the competition page, the one
            // thing every row is ultimately a pointer to.
            guard let competition = competition(for: ids.first),
                  let url = URL(string: competition.url) else { return }
            openURL(url)
        }
    }

    /// The window tracks ONE expanded/selected competition, so the table's
    /// multi-select surface narrows to that single value.
    private var singleSelection: Binding<Set<PersistentIdentifier>> {
        Binding {
            selectedID.map { [$0] } ?? []
        } set: { chosen in
            selectedID = chosen.first
        }
    }

    private func competition(for id: PersistentIdentifier?) -> Competition? {
        guard let id else { return nil }
        return rows.first { $0.persistentModelID == id }
    }

    /// Same greyed treatment the list gives finished competitions.
    private func cell(_ competition: Competition,
                      @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(competition.isCurrent() ? 1 : 0.55)
    }

    // MARK: One sort truth

    /// The table shows whatever `ListSort` says; a header click picks the
    /// matching case, and clicking the already-sorted column flips the
    /// direction - the spreadsheet contract. Direction lives in the shared
    /// `flipped` binding rather than a second table-only state, so the list
    /// style and the header chevron keep reading one truth.
    private var sortOrder: Binding<[KeyPathComparator<Competition>]> {
        Binding {
            var comparator = Self.comparator(for: sort)
            if flipped {
                comparator.order = comparator.order == .forward ? .reverse : .forward
            }
            return [comparator]
        } set: { order in
            guard let clicked = order.first,
                  let mapped = Self.listSort(for: clicked.keyPath) else { return }
            if mapped == sort {
                flipped.toggle()
            } else {
                // A new column starts at its canonical direction; MainWindow
                // resets `flipped` when it sees the sort change.
                sort = mapped
            }
        }
    }

    private static func comparator(for sort: ListSort) -> KeyPathComparator<Competition> {
        switch sort {
        case .deadline: KeyPathComparator(\.deadlineForSort, order: .forward)
        case .newest: KeyPathComparator(\.firstSeen, order: .reverse)
        case .prize: KeyPathComparator(\.prizeUSDForSort, order: .reverse)
        case .fit: KeyPathComparator(\.fitScoreForSort, order: .reverse)
        case .title: KeyPathComparator(\.title, order: .forward)
        case .source: KeyPathComparator(\.source, order: .forward)
        }
    }

    private static func listSort(for keyPath: PartialKeyPath<Competition>) -> ListSort? {
        if keyPath == \Competition.deadlineForSort { return .deadline }
        if keyPath == \Competition.firstSeen { return .newest }
        if keyPath == \Competition.prizeUSDForSort { return .prize }
        if keyPath == \Competition.fitScoreForSort { return .fit }
        if keyPath == \Competition.title { return .title }
        if keyPath == \Competition.source { return .source }
        return nil
    }
}

extension Competition {
    /// Comparator target for the When column: the same date its cell shows
    /// (`whenMoment`), dateless last - the rule `ListSort.deadline` sorts by.
    fileprivate var deadlineForSort: Date { whenMoment() ?? .distantFuture }
}
#endif
