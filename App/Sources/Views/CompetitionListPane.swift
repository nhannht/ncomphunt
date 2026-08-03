import CompHuntKit
import SwiftData
import SwiftUI

/// The results surface under the toolbar: rows, and - on the desktop - the
/// detail column or table that gives a wide window's width a job.
///
/// Layout per platform:
/// - iOS: chips over a single list, rows tap-to-expand in place.
/// - macOS `.list`: a split - the list in a ~420pt column, the selected
///   competition's full record filling the rest.
/// - macOS `.table`: a full-width sortable table, details in an inspector.
///
/// The chip row is the phone's category filter only. The desktop filters from
/// the sidebar column in `MainWindow`, so `categorySelection` and `markedOnly`
/// are read here on iOS alone.
/// One selection value drives all three; the styles are different projections
/// of the same state, never different states.
struct CompetitionListPane: View {
    let query: SearchQuery
    @Binding var sort: ListSort
    let grouping: ListGrouping
    /// Desktop layout choice; the phone ignores it.
    let style: ListStyle
    /// The chip row's read/write line into the query string.
    @Binding var categorySelection: CompetitionFilter?
    /// The Marked chip's line into the same string.
    @Binding var markedOnly: Bool
    /// Drop one constraint the person could not have known was the costly one.
    let onRelax: (QueryAxis) -> Void
    let onClear: () -> Void
    /// The one selected (iOS: expanded) row; nil means none. Tap toggles.
    @Binding var selectedID: PersistentIdentifier?

    @Environment(AppModel.self) private var model
    @Query private var competitions: [Competition]
    /// The single profile row, observed so a Settings edit re-ranks the
    /// list without a relaunch - the COMP-16 acceptance criterion.
    @Query private var profiles: [UserProfile]

    /// Matching rows: best text match first, finished competitions always last.
    /// The rule and the ordering live in the kit so both can be tested without
    /// a window; the subtitle reports when relevance is in charge and when
    /// nothing matched, so neither is ever silent.
    private var found: SearchResults {
        // Adopt the profile BEFORE sorting, in the same pass: an edit
        // changes the row, the @Query re-evaluates this body, and the fresh
        // snapshot is in place before any comparator or detail row reads
        // `fitValue`. An onChange would adopt only after a render had
        // already scored against the stale profile.
        FitContext.adopt(profiles.first?.snapshot() ?? .defaults)
        return query.results(from: competitions, tieBreak: sort.areInOrder)
    }

    private var isRanked: Bool { !query.terms.isEmpty }

    /// Groups keep the item sort inside them and appear in order of their
    /// best-ranked item, so under deadline sort the most urgent group leads.
    private func groups(of items: [Competition]) -> [(key: String, items: [Competition])] {
        var order: [String] = []
        var buckets: [String: [Competition]] = [:]
        for competition in items {
            let key = grouping.key(for: competition) ?? ""
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(competition)
        }
        return order.map { (key: $0, items: buckets[$0]!) }
    }

    var body: some View {
        let results = found
        let rows = results.items

        return layout(rows: rows)
            .navigationSubtitle(
                subtitle(
                    shown: rows.count,
                    ended: rows.count(where: { !$0.isCurrent() }),
                    fellBack: results.isFallback))
    }

    @ViewBuilder
    private func layout(rows: [Competition]) -> some View {
        // No chip row on the desktop: the category filter is the sidebar
        // column, and carrying both would be two controls writing the same
        // value, which is the disagreement this app keeps designing out.
        #if os(macOS)
        switch style {
        case .list:
            HSplitView {
                listOrEmpty(rows: rows)
                    .frame(minWidth: 320, idealWidth: 420, maxWidth: 560)
                CompetitionDetailPane(competition: selected)
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
        case .table:
            Group {
                if rows.isEmpty {
                    emptyState
                } else {
                    CompetitionTablePane(
                        rows: rows, selectedID: $selectedID, sort: $sort)
                }
            }
            .inspector(isPresented: inspectorShown) {
                CompetitionDetailPane(competition: selected)
                    .inspectorColumnWidth(min: 300, ideal: 360, max: 560)
            }
        }
        #else
        VStack(spacing: 0) {
            CategoryChipRow(selection: $categorySelection, markedOnly: $markedOnly)
            listOrEmpty(rows: rows)
        }
        #endif
    }

    @ViewBuilder
    private func listOrEmpty(rows: [Competition]) -> some View {
        if rows.isEmpty {
            emptyState
        } else {
            competitionList(rows: rows)
        }
    }

    private func competitionList(rows: [Competition]) -> some View {
        let now = Date.now
        let live = rows.filter { $0.isCurrent(asOf: now) }
        let ended = rows.filter { !$0.isCurrent(asOf: now) }

        return ScrollViewReader { proxy in
            List(selection: $selectedID) {
                if grouping == .none {
                    ForEach(live) { row($0) }
                    if !ended.isEmpty {
                        // Kept visible rather than filtered away: the one
                        // competition answering a search is worth showing
                        // even when it closed last week, as long as nothing
                        // pretends it is still open.
                        Section("Ended") {
                            ForEach(ended) { row($0) }
                        }
                    }
                } else {
                    ForEach(groups(of: rows), id: \.key) { group in
                        Section("\(group.key) (\(group.items.count))") {
                            ForEach(group.items) { row($0) }
                        }
                    }
                }
            }
            .onChange(of: selectedID) {
                // Minimal scroll: brings a deep-linked row on screen and
                // reveals a selected row's tail; a fully visible row does
                // not move.
                guard let selectedID else { return }
                withAnimation(.snappy) { proxy.scrollTo(selectedID) }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No competitions", systemImage: "trophy")
        } description: {
            Text(emptyDescription)
        } actions: {
            // A dead end becomes one click. Which constraint is
            // expensive is invisible from the query alone - a category
            // holding one current competition looks exactly like one
            // holding forty.
            if let diagnosis {
                Button("Remove \(diagnosis.axis.label)") {
                    onRelax(diagnosis.axis)
                }
            } else if !query.isEmpty {
                Button("Clear search") { onClear() }
            }
        }
    }

    #if os(macOS)
    /// Resolved against the full store, not the filtered rows, so narrowing
    /// the list does not blank a detail pane the person is still reading.
    private var selected: Competition? {
        guard let selectedID else { return nil }
        return competitions.first { $0.persistentModelID == selectedID }
    }

    /// The inspector is the selection, shown: closing it deselects, and
    /// selecting reopens it. No second "is the inspector open" state.
    private var inspectorShown: Binding<Bool> {
        Binding {
            selectedID != nil
        } set: { shown in
            if !shown { selectedID = nil }
        }
    }

    /// Desktop rows: List selection owns highlight, arrows, and the tap -
    /// the detail pane does the expanding, so the row stays a row.
    private func row(_ competition: Competition) -> some View {
        CompetitionRow(competition: competition)
            .tag(competition.persistentModelID)
            .id(competition.persistentModelID)
            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
            .contextMenu {
                CompetitionActionsMenu(competition: competition)
            }
    }
    #else
    /// Phone rows expand in place: there is no second pane to send detail to.
    private func row(_ competition: Competition) -> some View {
        let id = competition.persistentModelID
        let isExpanded = selectedID == id
        return VStack(alignment: .leading, spacing: 0) {
            CompetitionRow(competition: competition)
            if isExpanded {
                CompetitionExpandedView(competition: competition)
                    .padding(.top, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) {
                selectedID = isExpanded ? nil : id
            }
        }
        .id(id)
        .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        .contextMenu {
            CompetitionActionsMenu(competition: competition)
        }
    }
    #endif

    private func subtitle(shown: Int, ended: Int, fellBack: Bool) -> String {
        // The count is the whole list, and the ended part is a subset of it.
        var parts = ["\(shown)"]
        if ended > 0 { parts.append("\(ended) ended") }
        // Never let the fallback pass silently. Getting the whole list back
        // with no explanation is a worse confusion than a blank screen.
        if fellBack {
            parts.append("nothing matched, showing all")
        } else if isRanked {
            parts.append("best match")
        }
        if let last = model.lastRefresh {
            parts.append("updated \(last.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    /// Which single constraint is costing the most. Returns nil while anything
    /// is on screen, so the scan never runs on the common path.
    private var diagnosis: QueryDiagnosis? {
        guard !competitions.isEmpty else { return nil }
        return query.narrowestConstraint(in: competitions)
    }

    private var emptyDescription: String {
        if model.isRefreshing { return "Refreshing sources..." }
        if competitions.isEmpty { return "Press Refresh to pull from all sources." }
        if let diagnosis {
            let count = diagnosis.countWithout
            return """
                \(diagnosis.axis.label) narrows this to nothing. \
                Remove it to see \(count) competition\(count == 1 ? "" : "s").
                """
        }
        if !query.isEmpty {
            // Jointly unsatisfiable, so naming one axis would promise results
            // that removing it does not produce.
            return "No competition matches this combination."
        }
        return "Nothing matches this filter."
    }
}
