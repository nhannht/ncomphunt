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
///
/// One lush surface, then calm - the App Store product-page ration. The hero
/// band paints the brand gradient (the app's only "picture", since
/// competitions have no artwork) under white numerals; everything below is
/// the system Storage pane's idiom: monochrome numerals, neutral surfaces,
/// one thin composition bar per axis, quiet rows with hairline separators.
/// Color below the hero appears only as small identity dots and inside the
/// composition bars - never as card washes, tinted numerals, or per-row
/// capsules, which is how a dashboard stops looking native.
struct DashboardView: View {
    @Query private var competitions: [Competition]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// False for the first frame so the composition bars wipe into place on
    /// appear; under Reduce Motion they render full-width immediately.
    @State private var revealed = false

    private var stats: DashboardStats { DashboardStats(for: competitions) }

    var body: some View {
        ScrollView {
            let stats = stats
            if stats.total == 0 {
                ContentUnavailableView(
                    "Nothing indexed yet",
                    systemImage: "chart.bar",
                    description: Text("Refresh to pull from your sources."))
                    .padding(.top, 40)
            } else {
                VStack(spacing: 0) {
                    hero(stats)
                    VStack(alignment: .leading, spacing: 24) {
                        // The dashboard's honesty check: this is the number
                        // the reminder schedule is actually built from, so a
                        // surprising notification count has somewhere to be
                        // explained.
                        Text("\(stats.markedWithDeadline) marked competition\(stats.markedWithDeadline == 1 ? " has" : "s have") a deadline still ahead, which is what gets reminders. \(stats.ended) ended, \(stats.undated) have no dates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        pipeline(stats)
                        Divider()
                        kind(stats)
                        Divider()
                        source(stats)
                        Divider()
                        region(stats)
                    }
                    .padding(24)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Dashboard")
        .task { revealed = true }
    }

    // MARK: hero

    /// The at-a-glance numerals on the brand mesh, Weather-app style: the
    /// band is full-bleed, the content column stays aligned with the quiet
    /// sections below. White carries everything - a colored dot or numeral
    /// on the gradient would be decoration fighting decoration.
    private func hero(_ stats: DashboardStats) -> some View {
        HStack(spacing: 20) {
            heroStat(stats.total, "Indexed")
            heroDivider
            heroStat(stats.closingThisWeek, "Closing this week")
            heroDivider
            heroStat(stats.runningNow, "Running now")
            heroDivider
            heroStat(stats.marked, "Marked")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background { BrandMesh(animated: !reduceMotion) }
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 40)
    }

    private func heroStat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(Motion.state, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: pipeline

    private func pipeline(_ stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                heading("Your pipeline")
                Spacer()
                Text("\(stats.marked) of \(stats.total) marked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(Motion.state, value: stats.marked)
            }
            if stats.marked == 0 {
                Text("Nothing marked yet. Star a competition to track it here and be reminded before its deadline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                compositionBar(stats.byStatus.map { ($0.key.tint, $0.count) },
                               total: stats.marked)
                // All five states, zeroes included in tertiary - the funnel
                // keeps its slots even when the bar has nothing to show.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12,
                                             alignment: .leading)],
                          alignment: .leading, spacing: 6) {
                    ForEach(stats.byStatus) { tally in
                        legendItem(tally.key.displayName,
                                   tint: tally.key.tint,
                                   count: tally.count)
                    }
                }
            }
        }
    }

    // MARK: the three shapes

    private func kind(_ stats: DashboardStats) -> some View {
        let shown = stats.byCategory.filter { $0.count > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            heading("By kind")
            compositionBar(shown.map { ($0.key.tint, $0.count) },
                           total: stats.total)
            rows(shown, total: stats.total,
                 dot: { $0.tint }, label: { $0.displayName })
        }
    }

    /// Sources carry no identity color, so they get no composition bar and no
    /// dots - just the ranked table. Painting arbitrary hues on them is
    /// exactly the decoration this layout exists to avoid.
    private func source(_ stats: DashboardStats) -> some View {
        let shown = stats.bySource.filter { $0.count > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            heading("By source")
            rows(shown, total: stats.total, dot: nil, label: { $0 })
        }
    }

    private func region(_ stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Where")
            compositionBar(stats.byRegion.map { (regionTint($0.key), $0.count) },
                           total: stats.total)
            rows(stats.byRegion.filter { $0.count > 0 }, total: stats.total,
                 dot: regionTint, label: { $0.displayName })
        }
    }

    /// Vietnam wears the red its list rows already use; global stays neutral.
    private func regionTint(_ region: Region) -> Color {
        region == .vietnam ? .red : .gray
    }

    // MARK: shared pieces

    /// One thin capsule split proportionally between the non-zero slots - the
    /// Storage pane's composition bar. Wipes in from the leading edge on
    /// first appear; skipped under Reduce Motion.
    private func compositionBar(_ segments: [(tint: Color, count: Int)],
                                total: Int) -> some View {
        GeometryReader { geometry in
            let shown = segments.filter { $0.count > 0 }
            let gaps = CGFloat(max(shown.count - 1, 0)) * 2
            let available = max(geometry.size.width - gaps, 0)
            HStack(spacing: 2) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segment.tint)
                        .frame(width: available * CGFloat(segment.count)
                            / CGFloat(max(total, 1)))
                }
            }
            .clipShape(Capsule())
            .mask(alignment: .leading) {
                Capsule().frame(width: revealed ? geometry.size.width : 0)
            }
            .animation(reduceMotion ? nil : Motion.layout, value: revealed)
            .animation(reduceMotion ? nil : Motion.layout, value: shown.map(\.count))
        }
        .frame(height: 8)
    }

    /// The quiet table under a composition bar: dot, name, count, share of
    /// the whole store, hairline separators. No per-row bars - the
    /// composition bar above already carries the proportions.
    private func rows<Key>(
        _ tallies: [Tally<Key>], total: Int,
        dot: ((Key) -> Color)?, label: @escaping (Key) -> String
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(tallies) { tally in
                HStack(spacing: 8) {
                    if let dot {
                        CategoryDot(color: dot(tally.key), size: 8)
                    }
                    Text(label(tally.key))
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    Text("\(tally.count)")
                        .font(.callout.weight(.medium).monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(Motion.state, value: tally.count)
                    Text(Double(tally.count) / Double(max(total, 1)),
                         format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 6)
                if tally.id != tallies.last?.id {
                    Divider()
                }
            }
        }
    }

    private func legendItem(_ name: String, tint: Color, count: Int) -> some View {
        HStack(spacing: 5) {
            CategoryDot(color: count == 0 ? Color.gray.opacity(0.35) : tint, size: 8)
            Text(name)
                .foregroundStyle(count == 0 ? .tertiary : .secondary)
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(count == 0 ? .tertiary : .primary)
                .contentTransition(.numericText())
                .animation(Motion.state, value: count)
        }
        .font(.caption)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

/// The brand gradient - the App Store artboards' #D825FC > #1C3D7A > #3574F0 -
/// as a slowly breathing mesh. This is the app's one manufactured picture, so
/// it earns its animation: an ambient drift of the interior control points,
/// far below attention speed. Ambient motion is not a state change, so it is
/// driven by TimelineView time rather than a `Motion` curve; Reduce Motion
/// (or `animated: false`) pins it to a still frame.
private struct BrandMesh: View {
    let animated: Bool

    private static let magenta = Color(red: 216 / 255, green: 37 / 255, blue: 252 / 255)
    private static let navy = Color(red: 28 / 255, green: 61 / 255, blue: 122 / 255)
    private static let blue = Color(red: 53 / 255, green: 116 / 255, blue: 240 / 255)

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                mesh(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(at: 0)
        }
    }

    private func mesh(at t: TimeInterval) -> some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0],
                [drift(t, speed: 0.11, sway: 0.18), 0],
                [1, 0],
                [0, drift(t, speed: 0.09, phase: 1.0, sway: 0.15)],
                [drift(t, speed: 0.07, phase: 2.0, sway: 0.16),
                 drift(t, speed: 0.05, phase: 1.3, sway: 0.14)],
                [1, drift(t, speed: 0.08, phase: 0.6, sway: 0.15)],
                [0, 1],
                [drift(t, speed: 0.06, phase: 3.1, sway: 0.17), 1],
                [1, 1],
            ],
            colors: [
                Self.magenta, Self.magenta, Self.blue,
                Self.navy, Self.navy, Self.blue,
                Self.navy, Self.blue, Self.blue,
            ])
    }

    /// A control point's coordinate swaying around the grid midline. Speeds
    /// are in Hz, so the fastest point takes ~9 seconds per cycle.
    private func drift(_ t: TimeInterval, speed: Double,
                       phase: Double = 0, sway: Float) -> Float {
        0.5 + sway * Float(sin(t * speed * 2 * .pi + phase))
    }
}
