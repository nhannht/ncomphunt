import CompHuntKit
import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var competitions: [Competition]

    private var upcoming: [Competition] {
        let now = Date.now
        return competitions
            .filter { $0.isCurrent(asOf: now) && $0.nextRelevantDate != nil }
            .sorted { ($0.nextRelevantDate ?? .distantFuture) < ($1.nextRelevantDate ?? .distantFuture) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        if upcoming.isEmpty {
            Text("No upcoming deadlines")
        } else {
            Section("Next deadlines") {
                ForEach(upcoming) { competition in
                    Button {
                        if let url = URL(string: competition.url) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text(menuLine(for: competition))
                    }
                }
            }
        }

        Divider()

        Button("Open nCompHunt") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(model.isRefreshing ? "Refreshing..." : "Refresh Now") {
            Task { await model.refresh() }
        }
        .disabled(model.isRefreshing)

        if let last = model.lastRefresh {
            Text("Updated \(last.formatted(.relative(presentation: .named)))")
        }

        Divider()

        Button("Quit nCompHunt") {
            NSApp.terminate(nil)
        }
    }

    private func menuLine(for competition: Competition) -> String {
        var line = competition.title
        if line.count > 44 {
            line = String(line.prefix(43)) + "..."
        }
        if let date = competition.nextRelevantDate {
            line += "  (\(date.formatted(.relative(presentation: .named))))"
        }
        return line
    }
}
