import Foundation

/// A tiny, process-portable view of the next few contests, written by the app
/// into the App Group container and read by the widget. Deliberately free of
/// SwiftData: the sandboxed widget decodes plain values and never opens the
/// store. `date` is the countdown target (registration deadline / start / end).
public struct WidgetContest: Codable, Sendable, Equatable, Identifiable {
    public let key: String
    public let title: String
    public let categoryCode: String
    public let url: String
    public let date: Date?

    public var id: String { key }

    public init(key: String, title: String, categoryCode: String, url: String, date: Date?) {
        self.key = key
        self.title = title
        self.categoryCode = categoryCode
        self.url = url
        self.date = date
    }
}

/// The featured row: the best-fit competition, resolved by the APP before the
/// snapshot crosses the App Group boundary (COMP-19). Plain values only - the
/// widget never runs the scorer or opens the store; the score, headline, and
/// strongest reason travel pre-computed.
public struct WidgetTopPick: Codable, Sendable, Equatable {
    public let contest: WidgetContest
    /// The 0-100 fit score at write time.
    public let score: Int
    /// The verdict band phrase: "Strong fit", "Good fit", ...
    public let headline: String
    /// The strongest reason behind the score, nil when nothing moved it.
    public let reason: String?

    public init(contest: WidgetContest, score: Int, headline: String, reason: String?) {
        self.contest = contest
        self.score = score
        self.headline = headline
        self.reason = reason
    }
}

/// The snapshot the widget renders. `generatedAt` lets the widget show staleness
/// if the app has not refreshed in a while. `topPick` is optional end to end:
/// a snapshot written by an older build has no such key, decodes to nil, and
/// the widget falls back to the soonest-first list - a stale file can never
/// break rendering.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let contests: [WidgetContest]
    public let topPick: WidgetTopPick?

    public init(generatedAt: Date, contests: [WidgetContest],
                topPick: WidgetTopPick? = nil) {
        self.generatedAt = generatedAt
        self.contests = contests
        self.topPick = topPick
    }
}

/// Build the snapshot from the live store: the next `limit` upcoming contests
/// across all verticals (unfiltered - the widget is a standalone glance, not the
/// filtered list window). Reuses `upcomingContests` and `shortCode` so the widget
/// and the app agree on selection and badges. The top pick is ranked here, in
/// the app process, against the profile and busy windows it passes in - the
/// widget only ever decodes the result.
public func widgetSnapshot(
    from competitions: [Competition],
    limit: Int = 6,
    profile: ProfileSnapshot,
    busy: [DateInterval] = [],
    now: Date = .now
) -> WidgetSnapshot {
    let upcoming = upcomingContests(
        in: competitions, category: nil, region: nil, limit: limit, now: now)
    let contests = upcoming.map(WidgetContest.init)
    let pick = FitScorer.topPick(
        in: competitions, profile: profile, busy: busy, now: now
    ).map { pick in
        WidgetTopPick(
            contest: WidgetContest(pick.competition),
            score: pick.fit.score,
            headline: pick.fit.headline,
            reason: pick.fit.reasons.first)
    }
    return WidgetSnapshot(generatedAt: now, contests: contests, topPick: pick)
}

extension WidgetContest {
    /// The portable projection of a live row, shared by the list and the
    /// top pick so the two can never disagree on a field.
    init(_ competition: Competition) {
        self.init(
            key: competition.key,
            title: competition.title,
            categoryCode: competition.category.shortCode,
            url: competition.url,
            date: competition.nextRelevantDate)
    }
}

/// Encode the snapshot to the App Group container (atomic). No-op if the
/// container is unavailable - the widget then falls back to its placeholder.
public func writeWidgetSnapshot(_ snapshot: WidgetSnapshot) {
    guard let url = AppGroup.snapshotURL,
          let data = try? JSONEncoder().encode(snapshot) else { return }
    try? data.write(to: url, options: .atomic)
}

/// Decode the snapshot the app last wrote; nil if none exists yet.
public func readWidgetSnapshot() -> WidgetSnapshot? {
    guard let url = AppGroup.snapshotURL,
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
}
