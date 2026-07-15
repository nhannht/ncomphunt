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

/// The snapshot the widget renders. `generatedAt` lets the widget show staleness
/// if the app has not refreshed in a while.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let contests: [WidgetContest]

    public init(generatedAt: Date, contests: [WidgetContest]) {
        self.generatedAt = generatedAt
        self.contests = contests
    }
}

/// Build the snapshot from the live store: the next `limit` upcoming contests
/// across all verticals (unfiltered - the widget is a standalone glance, not the
/// filtered list window). Reuses `upcomingContests` and `shortCode` so the widget
/// and the app agree on selection and badges.
public func widgetSnapshot(
    from competitions: [Competition],
    limit: Int = 6,
    now: Date = .now
) -> WidgetSnapshot {
    let upcoming = upcomingContests(
        in: competitions, category: nil, region: nil, limit: limit, now: now)
    let contests = upcoming.map { competition in
        WidgetContest(
            key: competition.key,
            title: competition.title,
            categoryCode: competition.category.shortCode,
            url: competition.url,
            date: competition.nextRelevantDate)
    }
    return WidgetSnapshot(generatedAt: now, contests: contests)
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
