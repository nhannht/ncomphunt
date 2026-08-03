import CompHuntKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ContestEntry: TimelineEntry {
    let date: Date
    let contests: [WidgetContest]
    /// The app-resolved best-fit pick (COMP-19); nil when the snapshot was
    /// written by an older build, so a stale file renders the plain list.
    let topPick: WidgetTopPick?
}

/// Reads the App Group snapshot the app writes. The countdown text updates on its
/// own (SwiftUI relative-time Text), so the timeline only needs to re-read the
/// LIST hourly - cheap on the WidgetKit reload budget.
struct ContestProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContestEntry {
        ContestEntry(date: .now, contests: Self.sample, topPick: Self.samplePick)
    }

    func getSnapshot(in context: Context, completion: @escaping (ContestEntry) -> Void) {
        if let snapshot = readWidgetSnapshot() {
            completion(ContestEntry(date: .now, contests: snapshot.contests,
                                    topPick: snapshot.topPick))
        } else {
            completion(ContestEntry(date: .now, contests: Self.sample,
                                    topPick: Self.samplePick))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContestEntry>) -> Void) {
        let now = Date.now
        let snapshot = readWidgetSnapshot()
        let entry = ContestEntry(date: now, contests: snapshot?.contests ?? [],
                                 topPick: snapshot?.topPick)
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

    static let samplePick = WidgetTopPick(
        contest: sample[1], score: 85, headline: "Strong fit",
        reason: "Competitive Programming matches your interests")
}

// MARK: - Deep link

/// Tapping a widget row opens the app to that contest: ncomphunt://open?key=...
/// Shares the kit's one constructor with the reminder-tap route.
private func deepLink(for contest: WidgetContest) -> URL {
    competitionDeepLink(key: contest.key)
}

// MARK: - Views

/// The tiny category marker, colored through the kit's single mapping so the
/// widget can never drift from the app again. An empty code reads as
/// uncategorized gray.
@MainActor
private func categoryDot(_ code: String) -> CategoryDot {
    CategoryDot(color: CompetitionCategory.tint(forCode: code))
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
            categoryDot(contest.categoryCode)
            Text(contest.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Countdown(date: contest.date)
        }
    }
}

/// Small family: ONE featured competition - the best-fit pick with its
/// strongest reason when the snapshot carries one, else the soonest contest
/// (the older-build and empty-profile fallback).
private struct SmallView: View {
    let pick: WidgetTopPick?
    let next: WidgetContest?

    private var featured: WidgetContest? { pick?.contest ?? next }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                Text(pick != nil ? "Top pick" : "Next contest")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let featured {
                HStack(alignment: .top, spacing: 4) {
                    categoryDot(featured.categoryCode)
                        .padding(.top, 4)
                    Text(featured.title).font(.footnote.weight(.semibold)).lineLimit(2)
                }
                if let reason = pick?.reason {
                    Text(reason).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Countdown(date: featured.date).font(.caption)
            } else {
                Spacer(minLength: 0)
                Text("No upcoming contests").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(featured.map(deepLink))
    }
}

/// Medium family: the pick featured on top with its verdict line, then the
/// next deadlines (excluding the pick - one row per competition, never two).
/// Without a pick, the plain four-row list this widget always rendered.
private struct MediumView: View {
    let contests: [WidgetContest]
    let pick: WidgetTopPick?

    private var deadlines: [WidgetContest] {
        guard let pick else { return Array(contests.prefix(4)) }
        return Array(contests.filter { $0.key != pick.contest.key }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pick {
                Link(destination: deepLink(for: pick.contest)) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            Text(pick.contest.title)
                                .font(.caption.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 4)
                            Countdown(date: pick.contest.date)
                        }
                        Text(pick.reason.map { "\(pick.headline) · \($0)" } ?? pick.headline)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Divider()
            } else {
                HStack {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text("Upcoming contests").font(.caption.weight(.semibold))
                }
            }
            if deadlines.isEmpty && pick == nil {
                Spacer(minLength: 0)
                Text("No upcoming contests").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(deadlines) { contest in
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
                SmallView(pick: entry.topPick, next: entry.contests.first)
            default:
                MediumView(contests: entry.contests, pick: entry.topPick)
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
