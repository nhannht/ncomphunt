import CompHuntKit
import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var filter: CompetitionFilter = .all
    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""
    @AppStorage("list.sort") private var sort: ListSort = .deadline
    @AppStorage("list.grouping") private var grouping: ListGrouping = .none
    @AppStorage("list.region") private var region: RegionFilter = .all

    var body: some View {
        NavigationSplitView {
            List(CompetitionFilter.allCases, selection: $filter) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            CompetitionListPane(
                filter: filter, region: region, searchText: searchText, sort: sort,
                grouping: grouping, selectedID: $selectedID)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            CompetitionDetailPane(selectedID: selectedID)
        }
        .searchable(text: $searchText, prompt: "Search competitions")
        .navigationTitle("nCompHunt")
        .toolbar {
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
        }
    }
}

struct CompetitionListPane: View {
    let filter: CompetitionFilter
    let region: RegionFilter
    let searchText: String
    let sort: ListSort
    let grouping: ListGrouping
    @Binding var selectedID: PersistentIdentifier?

    @Environment(AppModel.self) private var model
    @Query private var competitions: [Competition]

    private var visible: [Competition] {
        let now = Date.now
        return competitions
            .filter { $0.isCurrent(asOf: now) && filter.matches($0) && region.matches($0) }
            .filter {
                searchText.isEmpty
                    || $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.organizer.localizedCaseInsensitiveContains(searchText)
            }
            .sorted(by: sort.areInOrder)
    }

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
        .navigationTitle(filter.label)
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
        if let last = model.lastRefresh {
            parts.append("updated \(last.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    private var emptyDescription: String {
        if model.isRefreshing { return "Refreshing sources..." }
        if competitions.isEmpty { return "Press Refresh to pull from all sources." }
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
