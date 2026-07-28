import CompHuntKit
import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: PersistentIdentifier?

    /// Everything the person is filtering and searching by, as text.
    ///
    /// The single source of truth. The sidebar and the region menu do not hold
    /// their own state - they WRITE into this string and read their appearance
    /// back out of it. That is what removes the class of bug where a chip said
    /// one thing while the sidebar said another: with one value there is
    /// nothing to disagree.
    @AppStorage("list.query") private var queryText = ""
    @AppStorage("list.sort") private var sort: ListSort = .deadline
    @AppStorage("list.grouping") private var grouping: ListGrouping = .none

    /// Derived, never read here. Written on every query change purely so the
    /// menu bar and the widget - which take ONE optional category and ONE
    /// optional region - keep working. See `syncMenuBarLens`.
    @AppStorage("list.filter") private var menuBarCategory: CompetitionFilter = .all
    @AppStorage("list.region") private var menuBarRegion: RegionFilter = .all

    @State private var isResolving = false
    @State private var queryMessage: String?

    private var query: SearchQuery { SearchQuery.parse(queryText) }

    /// Present only in a build that registered a generator.
    private var generator: (any QueryGenerating)? { ProRegistry.queryGenerator }

    var body: some View {
        NavigationSplitView {
            List(CompetitionFilter.allCases, selection: sidebarSelection) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            VStack(spacing: 0) {
                if let queryMessage {
                    Text(queryMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    Divider()
                }
                CompetitionListPane(
                    query: query, title: paneTitle, sort: sort,
                    grouping: grouping, onRelax: relax, onClear: clearFilters,
                    selectedID: $selectedID)
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            CompetitionDetailPane(selectedID: selectedID)
        }
        .searchable(text: $queryText, prompt: searchPrompt)
        .searchSuggestions {
            ForEach(SearchQuery.suggestions(for: queryText)) { suggestion in
                HStack {
                    Text(suggestion.label)
                    Spacer()
                    Text(suggestion.detail)
                        .foregroundStyle(.secondary)
                }
                .searchCompletion(suggestion.completion)
            }
        }
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
                                    || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help(generator.unavailableReason
                                ?? "Turn what you typed into filters")
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
                    Picker("Region", selection: regionSelection) {
                        ForEach(RegionFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Filter by region", systemImage: regionSelection.wrappedValue.isActive
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
            adoptLegacyFilters()
            model.startAutoRefresh()
            applyDeepLinkSelection()
        }
        .onChange(of: queryText) {
            queryMessage = nil
            syncMenuBarLens()
        }
        .onChange(of: model.deepLinkSelection) { applyDeepLinkSelection() }
    }

    // MARK: Controls that write into the query

    /// The sidebar reads its highlight out of the query and writes back into it.
    ///
    /// Several categories cannot be shown as one highlighted row, so the
    /// selection falls back to "All" then. The query still holds them and the
    /// list still honours them - the sidebar simply cannot draw that state, and
    /// inventing a fake one would be worse than admitting it.
    private var sidebarSelection: Binding<CompetitionFilter> {
        Binding {
            guard query.categories.count == 1, let only = query.categories.first
            else { return .all }
            return .category(only)
        } set: { chosen in
            var updated = query
            updated.categories = chosen.categoryValue.map { [$0] } ?? []
            queryText = updated.serialized()
        }
    }

    private var regionSelection: Binding<RegionFilter> {
        Binding {
            guard query.regions.count == 1, let only = query.regions.first
            else { return .all }
            return RegionFilter(only)
        } set: { chosen in
            var updated = query
            updated.regions = chosen.regionValue.map { [$0] } ?? []
            queryText = updated.serialized()
        }
    }

    /// Keep the countdown and the widget working across a signature they do not
    /// share with the query.
    ///
    /// `nextUpcoming` takes ONE optional category and ONE optional region;
    /// a query carries sets. The rule, deliberately narrow: a query naming
    /// exactly one category persists it, and zero or several persists "all".
    /// The menu bar tracks a LENS, not a search - it counts down to the next
    /// contest worth knowing about, and free text has no bearing on that.
    private func syncMenuBarLens() {
        menuBarCategory = query.categories.count == 1
            ? .category(query.categories.first!) : .all
        menuBarRegion = query.regions.count == 1
            ? RegionFilter(query.regions.first!) : .all
        model.recomputeMenuBar()
    }

    /// Carry a pre-query install's sidebar and region choice into the query
    /// text, once. Without this an update silently resets what someone was
    /// looking at, including their menu-bar countdown.
    private func adoptLegacyFilters() {
        guard queryText.isEmpty else { return }
        var adopted = SearchQuery()
        if let category = menuBarCategory.categoryValue { adopted.categories = [category] }
        if let region = menuBarRegion.regionValue { adopted.regions = [region] }
        guard !adopted.isEmpty else { return }
        queryText = adopted.serialized()
    }

    // MARK: Presentation

    private var searchPrompt: String {
        generator == nil
            ? "Search, or filter with category:"
            : "Search, or describe what you want and press Return"
    }

    private var paneTitle: String {
        if query.hasFreeText { return "Results" }
        if query.categories.count == 1, let only = query.categories.first {
            return only.displayName
        }
        return "All"
    }

    // MARK: Actions

    /// Hand the typed sentence to the generator and let it rewrite the query.
    ///
    /// The result lands in the search field as the same operator syntax a
    /// person types by hand. That is the whole reason this is text: whatever
    /// the model decided is visible, editable, and correctable in the one place
    /// they were already looking, rather than an opaque state they can only
    /// accept or discard.
    private func resolveSearchText() {
        guard let generator, generator.unavailableReason == nil else { return }
        let text = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResolving else { return }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let resolved = try await generator.generate(from: text, now: .now)
                if resolved.isEmpty {
                    queryMessage = "Nothing in that named a category, region, or timeframe."
                } else {
                    queryText = resolved.serialized()
                }
            } catch {
                queryMessage = error.localizedDescription
            }
        }
    }

    /// Drop one constraint the person could not have known was the costly one.
    private func relax(_ axis: QueryAxis) {
        var updated = query
        updated.remove(axis)
        queryText = updated.serialized()
    }

    private func clearFilters() {
        queryText = ""
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
    let query: SearchQuery
    let title: String
    let sort: ListSort
    let grouping: ListGrouping
    /// Drop one constraint the person could not have known was the costly one.
    let onRelax: (QueryAxis) -> Void
    let onClear: () -> Void
    @Binding var selectedID: PersistentIdentifier?

    @Environment(AppModel.self) private var model
    @Query private var competitions: [Competition]

    /// Matching rows: best text match first, finished competitions always last.
    /// The rule and the ordering live in the kit so both can be tested without
    /// a window; the subtitle reports when relevance is in charge and when
    /// nothing matched, so neither is ever silent.
    private var found: SearchResults {
        query.results(from: competitions, tieBreak: sort.areInOrder)
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
        let now = Date.now
        let live = rows.filter { $0.isCurrent(asOf: now) }
        let ended = rows.filter { !$0.isCurrent(asOf: now) }

        return Group {
            if rows.isEmpty {
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
            } else {
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
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(
            subtitle(shown: rows.count, ended: ended.count, fellBack: results.isFallback))
    }

    private func row(_ competition: Competition) -> some View {
        CompetitionRow(competition: competition)
            .tag(competition.persistentModelID)
            .contextMenu {
                CompetitionActionsMenu(competition: competition)
            }
    }

    private func subtitle(shown: Int, ended: Int, fellBack: Bool) -> String {
        // The count is the whole list, and the ended part is a subset of it.
        // Counting only live rows read as though "1 shown - 1 ended" might be
        // one row or two.
        var parts = ["\(shown) shown"]
        if ended > 0 { parts.append("\(ended) ended") }
        // Never let the fallback pass silently. Getting the whole list back
        // with no explanation is a worse confusion than a blank screen.
        if fellBack {
            parts.append("nothing matched, showing all")
        } else if isRanked {
            parts.append("best match first")
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
