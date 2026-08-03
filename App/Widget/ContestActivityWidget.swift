// The Widget directory compiles into BOTH widget targets (project.yml), so the
// os guard is what keeps the macOS extension building: ActivityKit's types are
// unavailable there.
#if os(iOS)
import ActivityKit
import CompHuntKit
import SwiftUI
import WidgetKit

/// The Live Activity for one followed contest (COMP-37): a countdown in the
/// Dynamic Island and on the Lock Screen. Render-only - the faces and their
/// flip moments are decided by `ContestActivityPlan` in the kit, and the app's
/// `ContestActivities` applies updates. Timer-driven by the system
/// (`Text(timerInterval:)` / `ProgressView(timerInterval:)`): no push updates,
/// nothing running server-side.
struct ContestActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ContestActivityAttributes.self) { context in
            LockScreenCard(context: context)
        } dynamicIsland: { context in
            let tint = CompetitionCategory.tint(forCode: context.attributes.categoryCode)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        CategoryDot(color: tint, size: 10)
                        if !context.attributes.categoryCode.isEmpty {
                            Text(context.attributes.categoryCode)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(target: context.state.target)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedDetail(context: context)
                }
            } compactLeading: {
                CategoryDot(color: tint, size: 8)
            } compactTrailing: {
                CountdownText(target: context.state.target)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .frame(maxWidth: 52)
            } minimal: {
                CategoryDot(color: tint, size: 8)
            }
            .widgetURL(competitionDeepLink(key: context.attributes.key))
            .keylineTint(tint)
        }
    }
}

/// The verb line every surface shares, via the kit's one wording source.
private struct PhaseLine: View {
    let state: ContestActivityAttributes.ContentState

    var body: some View {
        Text("\(state.phase.countdownLabel) in")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Start time and duration, shown while they are still ahead; the running
/// face replaces them with the progress bar, which says the same thing better.
private struct ScheduleLine: View {
    let state: ContestActivityAttributes.ContentState

    var body: some View {
        if state.phase != .running, let start = state.start {
            let when = start.formatted(date: .abbreviated, time: .shortened)
            if let end = state.end {
                Text("\(when) · runs \(compactCountdown(to: end, now: start))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(when)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Shared by the island's expanded bottom region and the Lock Screen card.
private struct ExpandedDetail: View {
    let context: ActivityViewContext<ContestActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context.attributes.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            PhaseLine(state: context.state)
            ScheduleLine(state: context.state)
            if context.state.phase == .running,
               let start = context.state.start, let end = context.state.end {
                ProgressView(timerInterval: start...end, countsDown: false) {
                } currentValueLabel: {
                }
                .tint(CompetitionCategory.tint(forCode: context.attributes.categoryCode))
            }
        }
    }
}

/// Lock Screen and banner presentation: the expanded content plus the big
/// countdown, in one card.
private struct LockScreenCard: View {
    let context: ActivityViewContext<ContestActivityAttributes>

    var body: some View {
        let tint = CompetitionCategory.tint(forCode: context.attributes.categoryCode)
        HStack(alignment: .top, spacing: 8) {
            CategoryDot(color: tint, size: 10)
                .padding(.top, 4)
            ExpandedDetail(context: context)
            Spacer(minLength: 8)
            CountdownText(target: context.state.target)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: 88, alignment: .trailing)
        }
        .padding(12)
        .activityBackgroundTint(nil)
        .widgetURL(competitionDeepLink(key: context.attributes.key))
    }
}
#endif
