import CompHuntKit
import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: PersistentIdentifier?

    /// Everything the person is filtering and searching by, as text.
    ///
    /// The single source of truth. The chip row and the region menu do not hold
    /// their own state - they WRITE into this string and read their appearance
    /// back out of it. That is what removes the class of bug where a chip said
    /// one thing while the list said another: with one value there is
    /// nothing to disagree.
    @AppStorage("list.query") private var queryText = ""
    @AppStorage("list.sort") private var sort: ListSort = .deadline
    @AppStorage("list.grouping") private var grouping: ListGrouping = .none
    /// Desktop layout: list-plus-detail split, or the full-width table.
    /// Stored but unread on iOS, which always shows the single list.
    @AppStorage("list.style") private var style: ListStyle = .list

    /// Derived, never read here. Written on every query change purely so the
    /// menu bar and the widget - which take ONE optional category and ONE
    /// optional region - keep working. See `syncMenuBarLens`.
    @AppStorage("list.filter") private var menuBarCategory: CompetitionFilter = .all
    @AppStorage("list.region") private var menuBarRegion: RegionFilter = .all

    @State private var isResolving = false
    @State private var queryMessage: String?
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    /// iOS has no Settings scene; the gear button presents the same form.
    @State private var settingsPresented = false
    /// Nor a second window, so the dashboard is a sheet here.
    @State private var dashboardPresented = false
    #endif

    private var query: SearchQuery { SearchQuery.parse(queryText) }

    /// On-device natural-language filtering, free on every platform. The value
    /// is stateless; availability is re-read from `unavailableReason` because
    /// Apple Intelligence can be toggled while the app runs.
    private let generator = NLFilterGenerator()

    var body: some View {
        shell
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

    /// The window's outer shape, and the one place the platforms genuinely
    /// differ. The desktop puts the category filter in a sidebar column, where
    /// there is width to spare; the phone keeps the chip row, where there is
    /// not. Ten categories overflowed the chip row's single scrolling line -
    /// Academic sat past the right edge, off screen - and a filter you have to
    /// scroll sideways to find is not a filter.
    @ViewBuilder
    private var shell: some View {
        #if os(macOS)
        NavigationSplitView {
            CategorySidebar(selection: categorySelection, markedOnly: markedOnly)
                .navigationSplitViewColumnWidth(min: 150, ideal: 172, max: 220)
        } detail: {
            content
        }
        .frame(minWidth: 860, minHeight: 420)
        #else
        NavigationStack {
            content
        }
        .sheet(isPresented: $settingsPresented) {
            NavigationStack {
                SettingsView()
                    .environment(model)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { settingsPresented = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $dashboardPresented) {
            NavigationStack {
                DashboardView()
                    .environment(model)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dashboardPresented = false }
                        }
                    }
            }
        }
        .eventEditSheet()
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let queryMessage {
                Text(queryMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
            CompetitionListPane(
                query: query, sort: $sort,
                grouping: grouping, style: style,
                categorySelection: categorySelection,
                markedOnly: markedOnly,
                onRelax: relax, onClear: clearFilters,
                selectedID: $selectedID)
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Picker("Layout", selection: $style) {
                    ForEach(ListStyle.allCases) { style in
                        Label(style.label, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .help("Switch between the list and the table")
            }
            #endif
            // One group, not three items across two placements. Mixing
            // .primaryAction with .secondaryAction let the system put the
            // view-options menu in its own region, so it floated alone in
            // the middle of the title bar with uneven gaps either side.
            // Buttons that belong together have to be declared together.
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Dashboard", systemImage: "chart.bar") {
                    #if os(macOS)
                    openWindow(id: CompHuntRoot.dashboardWindowID)
                    #else
                    dashboardPresented = true
                    #endif
                }
                .help("See the shape of your list and your pipeline")

                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(ListSort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Picker("Group by", selection: $grouping) {
                        ForEach(ListGrouping.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    // The table is flat by design; a disabled picker says
                    // so, where an ignored one would just lie.
                    .disabled(groupingUnavailable)
                    Picker("Region", selection: regionSelection) {
                        ForEach(RegionFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("View options", systemImage: regionSelection.wrappedValue.isActive
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
                .help("Sort, group, and filter by region")

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

                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await model.refresh() }
                    }
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gear") { settingsPresented = true }
            }
            #endif
        }
    }

    // MARK: Controls that write into the query

    /// The chip row reads its highlight out of the query and writes back into it.
    ///
    /// Several categories cannot be shown as one highlighted chip, so the
    /// selection falls back to "All" then. The query still holds them and the
    /// list still honours them - the chip row simply cannot draw that state, and
    /// inventing a fake one would be worse than admitting it.
    private var categorySelection: Binding<CompetitionFilter?> {
        Binding {
            guard query.categories.count == 1, let only = query.categories.first
            else { return .all }
            return .category(only)
        } set: { chosen in
            var updated = query
            updated.categories = (chosen ?? .all).categoryValue.map { [$0] } ?? []
            queryText = updated.serialized()
        }
    }

    /// The Marked chip, on the same read-out-of-the-query, write-back-into-it
    /// line as the category chips. On means `status:any`, so the one place the
    /// truth lives is still the query string.
    private var markedOnly: Binding<Bool> {
        Binding {
            query.isMarkedOnly
        } set: { wanted in
            var updated = query
            updated.statuses = wanted ? Set(CompetitionStatus.allCases) : []
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

    /// Grouping only shapes the list; the table is deliberately flat.
    private var groupingUnavailable: Bool {
        #if os(macOS)
        return style == .table
        #else
        return false
        #endif
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
        generator.unavailableReason == nil
            ? "Search, or describe what you want and press Return"
            : "Search, or filter with category:"
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
        guard generator.unavailableReason == nil else { return }
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

    /// Select the row a widget deep link staged, then clear it so a repeat tap
    /// on the same contest re-selects it. The list scrolls to whatever
    /// `selectedID` becomes, so no separate scroll channel is needed.
    private func applyDeepLinkSelection() {
        guard let target = model.deepLinkSelection else { return }
        selectedID = target
        model.clearDeepLinkSelection()
    }
}
