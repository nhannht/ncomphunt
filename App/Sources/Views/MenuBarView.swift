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

    /// The best-fit pick (COMP-19), under the same category/region lens the
    /// countdown label uses, so the dropdown explains the row the label is
    /// already counting down to.
    private var pick: (competition: Competition, fit: RankedCompetition)? {
        let category = CompetitionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.filter") ?? "all")?.categoryValue
        let region = RegionFilter(
            rawValue: UserDefaults.standard.string(forKey: "list.region") ?? "all")?.regionValue
        return FitScorer.topPick(
            in: competitions, category: category, region: region,
            profile: FitContext.current, busy: FitContext.currentBusy)
    }

    var body: some View {
        let pick = pick

        if let pick {
            Section("Top pick") {
                Button {
                    if let url = URL(string: pick.competition.url) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(menuLine(for: pick.competition))
                }
                Text(fitLine(for: pick.fit))
            }
        }

        // The pick already has its own row above; repeating it here would
        // read as two different competitions.
        let deadlines = upcoming.filter { $0.key != pick?.competition.key }
        if deadlines.isEmpty && pick == nil {
            Text("No upcoming deadlines")
        } else if !deadlines.isEmpty {
            Section("Next deadlines") {
                ForEach(deadlines) { competition in
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

    /// The why, as a disabled menu line under the pick: score, band, and the
    /// strongest reason when one exists.
    private func fitLine(for fit: RankedCompetition) -> String {
        var line = "fit \(fit.score) · \(fit.headline)"
        if let reason = fit.reasons.first {
            line += " · \(reason)"
        }
        return line
    }
}
