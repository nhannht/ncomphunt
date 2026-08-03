import CompHuntKit
import SwiftData
import SwiftUI

/// The shape of what you are holding, and what you have done about it.
///
/// Renders `DashboardStats` and computes nothing of its own, so what is on
/// screen cannot drift from what the rules in the kit say. Reads the whole
/// store rather than the window's current query: this answers "what have I
/// got", and a number that moved every time a chip was tapped would answer a
/// different question each time you looked.
struct DashboardView: View {
    @Query private var competitions: [Competition]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// False for the first frame so the bars grow into place on appear;
    /// under Reduce Motion the growth is skipped and they render full-width.
    @State private var revealed = false

    private var stats: DashboardStats { DashboardStats(for: competitions) }

    var body: some View {
        ScrollView {
            let stats = stats
            VStack(alignment: .leading, spacing: 22) {
                if stats.total == 0 {
                    ContentUnavailableView(
                        "Nothing indexed yet",
                        systemImage: "chart.bar",
                        description: Text("Refresh to pull from your sources."))
                        .padding(.top, 40)
                } else {
                    totals(stats)
                    pipeline(stats)
                    breakdown("By kind", stats.byCategory) { $0.displayName }
                    breakdown("By source", stats.bySource) { $0 }
                    breakdown("Where", stats.byRegion) { $0.displayName }
                }
            }
            .padding(20)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Dashboard")
        .task { revealed = true }
    }

    // MARK: totals

    private func totals(_ stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("At a glance")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)],
                      spacing: 10) {
                tile("Indexed", stats.total, .primary)
                tile("Closing this week", stats.closingThisWeek, .orange)
                tile("Running now", stats.runningNow, .green)
                tile("Marked", stats.marked, .yellow)
            }
            // The dashboard's honesty check: this is the number the reminder
            // schedule is actually built from, so a surprising notification
            // count has somewhere to be explained.
            Text("\(stats.markedWithDeadline) marked competition\(stats.markedWithDeadline == 1 ? " has" : "s have") a deadline still ahead, which is what gets reminders. \(stats.ended) ended, \(stats.undated) have no dates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func tile(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Motion.state, value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: pipeline

    private func pipeline(_ stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("Your pipeline")
            if stats.marked == 0 {
                Text("Nothing marked yet. Star a competition to track it here and be reminded before its deadline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let scale = DashboardStats.scale(for: stats.byStatus)
                ForEach(stats.byStatus) { tally in
                    bar(label: tally.key.displayName,
                        systemImage: tally.key.systemImage,
                        tint: tally.key.tint,
                        count: tally.count,
                        scale: scale)
                }
            }
        }
    }

    // MARK: breakdowns

    private func breakdown<Key>(
        _ title: String, _ tallies: [Tally<Key>],
        label: @escaping (Key) -> String
    ) -> some View {
        let shown = tallies.filter { $0.count > 0 }
        let scale = DashboardStats.scale(for: shown)
        return VStack(alignment: .leading, spacing: 8) {
            heading(title)
            ForEach(shown) { tally in
                bar(label: label(tally.key), systemImage: nil,
                    tint: tint(for: tally.key), count: tally.count, scale: scale)
            }
        }
    }

    /// Categories keep the tint the list already gives them, so the same colour
    /// means the same thing on both screens. Everything else is neutral rather
    /// than borrowing a category colour for an unrelated axis.
    private func tint<Key>(for key: Key) -> Color {
        (key as? CompetitionCategory)?.tint ?? .accentColor
    }

    private func bar(
        label: String, systemImage: String?, tint: Color, count: Int, scale: Int
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                Text(label).lineLimit(1)
            }
            .font(.callout)
            .frame(width: 132, alignment: .leading)

            GeometryReader { geometry in
                Capsule()
                    .fill(tint.opacity(count == 0 ? 0.15 : 0.75))
                    .frame(
                        // A zero row keeps a hairline so the funnel still reads
                        // as a row rather than as a gap. Bars grow from that
                        // hairline on first appear and re-flow on data change.
                        width: revealed
                            ? max(geometry.size.width
                                * CGFloat(count) / CGFloat(scale), 2)
                            : 2,
                        height: 12)
                    .frame(height: geometry.size.height, alignment: .center)
                    .animation(reduceMotion ? nil : Motion.layout, value: revealed)
                    .animation(reduceMotion ? nil : Motion.layout, value: count)
            }
            .frame(height: 16)

            Text("\(count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(count == 0 ? .tertiary : .secondary)
                .frame(width: 38, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(Motion.state, value: count)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }
}
