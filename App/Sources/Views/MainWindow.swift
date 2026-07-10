import CompHuntKit
import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @State private var filter: CompetitionFilter = .all
    @State private var selectedID: PersistentIdentifier?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List(CompetitionFilter.allCases, selection: $filter) { item in
                Label(item.label, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            CompetitionListPane(filter: filter, searchText: searchText, selectedID: $selectedID)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            CompetitionDetailPane(selectedID: selectedID)
        }
        .searchable(text: $searchText, prompt: "Search competitions")
        .navigationTitle("CompHunt")
        .toolbar {
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
    let searchText: String
    @Binding var selectedID: PersistentIdentifier?

    @Environment(AppModel.self) private var model
    @Query private var competitions: [Competition]

    private var visible: [Competition] {
        let now = Date.now
        return competitions
            .filter { $0.isCurrent(asOf: now) && filter.matches($0) }
            .filter {
                searchText.isEmpty
                    || $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.organizer.localizedCaseInsensitiveContains(searchText)
            }
            .sorted {
                ($0.nextRelevantDate ?? .distantFuture, $0.title)
                    < ($1.nextRelevantDate ?? .distantFuture, $1.title)
            }
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
                List(visible, selection: $selectedID) { competition in
                    CompetitionRow(competition: competition)
                        .tag(competition.persistentModelID)
                }
            }
        }
        .navigationTitle(filter.label)
        .navigationSubtitle(subtitle)
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
