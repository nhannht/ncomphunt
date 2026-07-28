import CompHuntKit
import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @AppStorage("list.filter") private var filter: CompetitionFilter = .all
    @AppStorage("list.sort") private var sort: ListSort = .deadline
    @AppStorage("list.grouping") private var grouping: ListGrouping = .none
    @AppStorage("list.region") private var region: RegionFilter = .all

    /// A resolved filter that has taken over from the controls, when one exists.
    ///
    /// Exactly one of these two drives the list at a time, and the precedence
    /// is unconditional: while this is non-nil it IS the filter, and touching
    /// any control puts the controls back in charge by clearing it. There is no
    /// merge, so there is never a moment where a chip and a control disagree
    /// about what is being shown.
    @State private var resolvedQuery: CompetitionQuery?
    @State private var isResolving = false
    @State private var queryMessage: String?

    /// The filter controls projected into the one value the list consumes.
    ///
    /// The controls stay the single source of truth for this path - a
    /// projection, not a copy - so there is nothing to keep in sync.
    private var controlsQuery: CompetitionQuery {
        CompetitionQuery(
            categories: filter.categoryValue.map { [$0] } ?? [],
            region: region.regionValue,
            // Free text is tokenized and ranks results rather than gating them,
            // so "open cup" now finds a title carrying both words apart and a
            // word nothing contains can no longer blank the list on its own.
            terms: CompetitionQuery.tokenize(searchText))
    }

    private var activeQuery: CompetitionQuery { resolvedQuery ?? controlsQuery }

    /// Present only in a build that registered a generator.
    private var generator: (any QueryGenerating)? { ProRegistry.queryGenerator }

    var body: some View {
        NavigationSplitView {
            List(CompetitionFilter.allCases, selection: $filter) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            VStack(spacing: 0) {
                if let resolvedQuery {
                    QueryChips(query: resolvedQuery) { updated in
                        // Clearing the last chip hands control back rather than
                        // leaving an empty filter that matches everything.
                        self.resolvedQuery = updated.isEmpty ? nil : updated
                    }
                    Divider()
                }
                if let queryMessage {
                    Text(queryMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    Divider()
                }
                CompetitionListPane(
                    query: activeQuery, title: paneTitle, sort: sort,
                    grouping: grouping, onRelax: relax, onClear: clearFilters,
                    selectedID: $selectedID)
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            CompetitionDetailPane(selectedID: selectedID)
        }
        .searchable(text: $searchText, prompt: searchPrompt)
        .onSubmit(of: .search, resolveSearchText)
        .navigationTitle("nCompHunt")
        .toolbar {
            if let generator {
                ToolbarItem(placement: .primaryAction) {
                    if isResolving {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Ask", systemImage: "sparkles", action: resolveSearchText)
                            .disabled(
                                generator.unavailableReason != nil
                                    || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help(generator.unavailableReason
                                ?? "Turn what you typed into a filter")
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(ListSort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Picker("Group by", selection: $grouping) {
                        ForEach(ListGrouping.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort and Group", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Picker("Region", selection: $region) {
                        ForEach(RegionFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Filter by region", systemImage: region.isActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await model.refresh() }
                    }
                }
            }
        }
        .task {
            model.startAutoRefresh()
            applyDeepLinkSelection()
        }
        // Touching a control hands the filter back to the controls. Without
        // this the sidebar would appear to do nothing while a resolved query
        // was active.
        .onChange(of: filter) { resolvedQuery = nil; model.recomputeMenuBar() }
        .onChange(of: region) { resolvedQuery = nil; model.recomputeMenuBar() }
        .onChange(of: searchText) {
            if !searchText.isEmpty { resolvedQuery = nil }
            queryMessage = nil
        }
        .onChange(of: model.deepLinkSelection) { applyDeepLinkSelection() }
    }

    private var searchPrompt: String {
        generator == nil
            ? "Search competitions"
            : "Search, or describe what you want and press Return"
    }

    private var paneTitle: String {
        resolvedQuery == nil ? filter.label : "Results"
    }

    /// Hand the typed sentence to the generator and let the result take over.
    ///
    /// Every failure path leaves the list exactly as it was and says why. A
    /// half-applied filter would be worse than none, because nothing on screen
    /// would reveal that it was partial.
    private func resolveSearchText() {
        guard let generator, generator.unavailableReason == nil else { return }
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResolving else { return }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let resolved = try await generator.generate(from: text, now: .now)
                if resolved.isEmpty {
                    queryMessage = "Nothing in that named a category, region, or timeframe."
                } else {
                    resolvedQuery = resolved
                    queryMessage = nil
                    // The sentence became the chips, so leaving it in the field
                    // would filter the results a second time by its literal text.
                    searchText = ""
                }
            } catch {
                queryMessage = error.localizedDescription
            }
        }
    }

    /// Drop one constraint, from whichever source currently owns the filter.
    ///
    /// The two sources are never merged - a resolved query replaces the
    /// controls wholesale - so the removal has to go to the one in charge, or
    /// it would appear to do nothing.
    private func relax(_ axis: QueryAxis) {
        if var resolved = resolvedQuery {
            resolved.remove(axis)
            resolvedQuery = resolved.isEmpty ? nil : resolved
            return
        }
        switch axis {
        case .category: filter = .all
        case .region: region = .all
        case .term: searchText = ""
        case .deadline:
            // The controls cannot express a date window; only a resolved query
            // can, and that branch returned above.
            break
        }
    }

    private func clearFilters() {
        resolvedQuery = nil
        searchText = ""
        filter = .all
        region = .all
        queryMessage = nil
    }

    /// Select the row a widget deep link staged, then clear it so a repeat tap on
    /// the same contest re-selects it.
    private func applyDeepLinkSelection() {
        guard let target = model.deepLinkSelection else { return }
        selectedID = target
        model.clearDeepLinkSelection()
    }
}

struct CompetitionListPane: View {
    let query: CompetitionQuery
    let title: String
    let sort: ListSort
    let grouping: ListGrouping
    /// Drop one constraint the person could not have known was the costly one.
    let onRelax: (QueryAxis) -> Void
    let onClear: () -> Void
    @Binding var selectedID: PersistentIdentifier?

    @Environment(AppModel.self) private var model
    @Query private var competitions: [Competition]

    /// Surviving rows, best text match first when text was typed.
    ///
    /// Relevance takes precedence over the chosen sort ONLY while free text is
    /// active, because a person who typed something is asking "which of these
    /// is what I meant" rather than "which is soonest". The chosen sort still
    /// breaks ties, and the subtitle says when this is happening so the
    /// reordering is never silent.
    private var visible: [Competition] {
        let now = Date.now
        let ranked = competitions.compactMap { competition -> (Competition, Int)? in
            guard competition.isCurrent(asOf: now),
                  let score = query.score(competition) else { return nil }
            return (competition, score)
        }
        guard isRanked else { return ranked.map(\.0).sorted(by: sort.areInOrder) }
        return ranked
            .sorted { a, b in
                a.1 == b.1 ? sort.areInOrder(a.0, b.0) : a.1 > b.1
            }
            .map(\.0)
    }

    private var isRanked: Bool { !query.terms.isEmpty }

    /// Groups keep the item sort inside them and appear in order of their
    /// best-ranked item, so under deadline sort the most urgent group leads.
    private var groups: [(key: String, items: [Competition])] {
        var order: [String] = []
        var buckets: [String: [Competition]] = [:]
        for competition in visible {
            let key = grouping.key(for: competition) ?? ""
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(competition)
        }
        return order.map { (key: $0, items: buckets[$0]!) }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView {
                    Label("No competitions", systemImage: "trophy")
                } description: {
                    Text(emptyDescription)
                } actions: {
                    // A dead end becomes one click. Which constraint is
                    // expensive is invisible from the chips alone - a category
                    // holding one current competition looks exactly like one
                    // holding forty.
                    if let diagnosis {
                        Button("Remove \(diagnosis.axis.label)") {
                            onRelax(diagnosis.axis)
                        }
                    } else if !query.isEmpty {
                        Button("Clear all filters") { onClear() }
                    }
                }
            } else {
                List(selection: $selectedID) {
                    if grouping == .none {
                        ForEach(visible) { competition in
                            row(competition)
                        }
                    } else {
                        ForEach(groups, id: \.key) { group in
                            Section("\(group.key) (\(group.items.count))") {
                                ForEach(group.items) { competition in
                                    row(competition)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
    }

    private func row(_ competition: Competition) -> some View {
        CompetitionRow(competition: competition)
            .tag(competition.persistentModelID)
            .contextMenu {
                CompetitionActionsMenu(competition: competition)
            }
    }

    private var subtitle: String {
        var parts = ["\(visible.count) shown"]
        if isRanked { parts.append("best match first") }
        if let last = model.lastRefresh {
            parts.append("updated \(last.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    /// Which single constraint is costing the most, computed only when the list
    /// is empty so the scan never runs on the common path.
    private var diagnosis: QueryDiagnosis? {
        guard visible.isEmpty, !competitions.isEmpty else { return nil }
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
            return "No current competition matches this combination."
        }
        return "Nothing matches this filter."
    }
}

struct CompetitionDetailPane: View {
    let selectedID: PersistentIdentifier?
    @Environment(\.modelContext) private var context

    var body: some View {
        if let selectedID,
           let competition = context.model(for: selectedID) as? Competition {
            CompetitionDetailView(competition: competition)
        } else {
            ContentUnavailableView(
                "Select a competition",
                systemImage: "trophy",
                description: Text("Pick one from the list to see details."))
        }
    }
}
