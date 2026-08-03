// The Widget directory compiles into BOTH widget targets (project.yml); the
// accessory families are Lock Screen / StandBy surfaces, so the whole file is
// iOS-only and the macOS extension never sees it.
#if os(iOS)
import CompHuntKit
import SwiftUI
import WidgetKit

/// The Lock Screen incarnation of the macOS menu-bar countdown (COMP-33):
/// the snapshot's best-fit pick (falling back to the soonest contest) as
/// shortCode + ticking countdown. Identity is TEXT, not `CategoryDot` -
/// accessory rendering is vibrant and desaturated, so color carries nothing
/// here, exactly why the menu bar leads with the code too.

/// One line above the clock: trophy + "CTF" + countdown, the `MenuBarLabel`
/// string. accessoryInline renders exactly one Label/Text, so the countdown
/// is concatenated as `Text` rather than composed as views.
struct InlineAccessoryView: View {
    let featured: WidgetContest?

    var body: some View {
        if let featured, let date = featured.date {
            Label {
                if featured.categoryCode.isEmpty {
                    CountdownText(target: date).text
                } else {
                    Text("\(featured.categoryCode) ") + CountdownText(target: date).text
                }
            } icon: {
                Image(systemName: "trophy")
            }
            .widgetURL(competitionDeepLink(key: featured.key))
        } else {
            Label("No contests", systemImage: "trophy")
        }
    }
}

/// The smallest face: code (or trophy when uncategorized) over the countdown.
struct CircularAccessoryView: View {
    let featured: WidgetContest?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let featured, let date = featured.date {
                VStack(spacing: 0) {
                    if featured.categoryCode.isEmpty {
                        Image(systemName: "trophy.fill").font(.caption2)
                    } else {
                        Text(featured.categoryCode)
                            .font(.caption2.weight(.semibold))
                    }
                    CountdownText(target: date, alignment: .center)
                        .font(.caption2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            } else {
                Image(systemName: "trophy")
            }
        }
        .widgetURL(featured.map { competitionDeepLink(key: $0.key) })
    }
}

/// Three lines beside the clock: title, code + countdown, and - when the
/// featured contest is the top pick - its fit reason.
struct RectangularAccessoryView: View {
    let featured: WidgetContest?
    /// The pick's reason line; nil when the snapshot has no pick (featured is
    /// then the soonest contest, which has no verdict to show).
    let reason: String?

    var body: some View {
        if let featured {
            VStack(alignment: .leading, spacing: 1) {
                Text(featured.title)
                    .font(.headline)
                    .lineLimit(reason == nil ? 2 : 1)
                HStack(spacing: 4) {
                    if !featured.categoryCode.isEmpty {
                        Text(featured.categoryCode)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let date = featured.date {
                        CountdownText(target: date, alignment: .leading)
                            .font(.caption2)
                    } else {
                        Text("soon").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let reason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(competitionDeepLink(key: featured.key))
        } else {
            Label("No upcoming contests", systemImage: "trophy")
                .font(.caption)
        }
    }
}
#endif
