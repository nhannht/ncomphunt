import CompHuntKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ContestEntry: TimelineEntry {
    let date: Date
    let contests: [WidgetContest]
}

/// Reads the App Group snapshot the app writes. The countdown text updates on its
/// own (SwiftUI relative-time Text), so the timeline only needs to re-read the
/// LIST hourly - cheap on the WidgetKit reload budget.
struct ContestProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContestEntry {
        ContestEntry(date: .now, contests: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ContestEntry) -> Void) {
        let contests = readWidgetSnapshot()?.contests ?? Self.sample
        completion(ContestEntry(date: .now, contests: contests))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContestEntry>) -> Void) {
        let now = Date.now
        let entry = ContestEntry(date: now, contests: readWidgetSnapshot()?.contests ?? [])
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    /// Shown in the widget gallery and while the app has not written a snapshot.
    static let sample = [
        WidgetContest(key: "s1", title: "picoCTF 2026", categoryCode: "CTF", url: "",
                      date: Date.now.addingTimeInterval(7_200)),
        WidgetContest(key: "s2", title: "Codeforces Round 1000", categoryCode: "CP", url: "",
                      date: Date.now.addingTimeInterval(93_600)),
        WidgetContest(key: "s3", title: "Kaggle Playground Series", categoryCode: "AI", url: "",
                      date: Date.now.addingTimeInterval(320_000)),
        WidgetContest(key: "s4", title: "Junction Hackathon", categoryCode: "Hack", url: "",
                      date: Date.now.addingTimeInterval(500_000)),
    ]
}

// MARK: - Deep link

/// Tapping a widget row opens the app to that contest: ncomphunt://open?key=...
private func deepLink(for contest: WidgetContest) -> URL {
    var components = URLComponents()
    components.scheme = "ncomphunt"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "key", value: contest.key)]
    return components.url ?? URL(string: "ncomphunt://open")!
}

private func badgeColor(_ code: String) -> Color {
    switch code {
    case "CP": .blue
    case "CTF": .red
    case "AI": .purple
    case "Hack": .orange
    case "Design": .pink
    default: .gray
    }
}

// MARK: - Views

private struct CategoryBadge: View {
    let code: String

    var body: some View {
        if code.isEmpty {
            Image(systemName: "trophy.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text(code)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(badgeColor(code).opacity(0.2), in: Capsule())
                .foregroundStyle(badgeColor(code))
        }
    }
}

/// A live "in 2 hours" string that updates without a timeline reload. Snapshot
/// contests always carry a date, but guard for safety.
private struct Countdown: View {
    let date: Date?

    var body: some View {
        if let date {
            Text(date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text("soon").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct ContestRow: View {
    let contest: WidgetContest

    var body: some View {
        HStack(spacing: 6) {
            CategoryBadge(code: contest.categoryCode)
            Text(contest.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Countdown(date: contest.date)
        }
    }
}

private struct SmallView: View {
    let contest: WidgetContest?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                Text("Next contest").font(.caption2).foregroundStyle(.secondary)
            }
            if let contest {
                CategoryBadge(code: contest.categoryCode)
                Text(contest.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                Spacer(minLength: 0)
                Countdown(date: contest.date).font(.caption)
            } else {
                Spacer(minLength: 0)
                Text("No upcoming contests").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(contest.map(deepLink))
    }
}

private struct MediumView: View {
    let contests: [WidgetContest]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                Text("Upcoming contests").font(.caption.weight(.semibold))
            }
            if contests.isEmpty {
                Spacer(minLength: 0)
                Text("No upcoming contests").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(contests.prefix(4)) { contest in
                    Link(destination: deepLink(for: contest)) {
                        ContestRow(contest: contest)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ContestEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallView(contest: entry.contests.first)
            default:
                MediumView(contests: entry.contests)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct UpcomingContestsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingContestsWidget", provider: ContestProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Contests")
        .description("The next competitions from nCompHunt, with a live countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
