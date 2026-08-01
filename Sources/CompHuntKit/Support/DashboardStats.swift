import Foundation

/// One row of a breakdown: a thing, and how many competitions are it.
public struct Tally<Key: Hashable & Sendable>: Sendable, Equatable, Identifiable {
    public let key: Key
    public let count: Int

    public var id: Key { key }

    public init(key: Key, count: Int) {
        self.key = key
        self.count = count
    }
}

/// Everything the dashboard shows, derived in one pass and testable without a
/// window. The view renders these numbers and computes nothing of its own, so
/// what is on screen cannot drift from what the rules here say.
///
/// Two halves that answer different questions:
///
/// ```
///   the pipeline   what have I done about these?     byStatus, marked
///   the shape      what am I actually holding?       totals, byCategory,
///                                                    bySource, byRegion
/// ```
public struct DashboardStats: Sendable, Equatable {
    // MARK: the pipeline

    /// In pipeline order, always all five states including the empty ones - a
    /// funnel with holes punched in it cannot be read as a funnel.
    public let byStatus: [Tally<CompetitionStatus>]
    public let marked: Int
    /// Marked, and still counting down to something. What the reminder schedule
    /// is actually derived from, so the two can be compared.
    public let markedWithDeadline: Int

    // MARK: the shape

    public let total: Int
    /// Started and not yet finished.
    public let runningNow: Int
    /// Next date falls inside the coming week.
    public let closingThisWeek: Int
    /// Nothing left to count down to.
    public let ended: Int
    /// No dates at all, mostly search hits. Called out rather than folded into
    /// `ended`, because a lead with no dates is not a competition that finished.
    public let undated: Int

    public let byCategory: [Tally<CompetitionCategory>]
    public let byRegion: [Tally<Region>]
    public let bySource: [Tally<String>]

    public static let horizonDays = 7

    public init(
        for competitions: [Competition],
        horizonDays: Int = horizonDays,
        now: Date = .now
    ) {
        let horizon = now.addingTimeInterval(Double(horizonDays) * 86_400)

        byStatus = CompetitionStatus.allCases.map { status in
            Tally(key: status, count: competitions.count { $0.status == status })
        }
        marked = competitions.count(where: \.isMarked)
        markedWithDeadline = competitions.count { competition in
            guard competition.wantsReminders else { return false }
            guard let next = competition.nextRelevantDate else { return false }
            return next >= now
        }

        total = competitions.count
        runningNow = competitions.count { competition in
            guard let start = competition.startDate, start <= now else { return false }
            guard let end = competition.endDate else { return false }
            return end >= now
        }
        closingThisWeek = competitions.count { competition in
            guard let next = competition.nextRelevantDate else { return false }
            return next >= now && next <= horizon
        }
        ended = competitions.count { !$0.isCurrent(asOf: now) }
        undated = competitions.count { $0.nextRelevantDate == nil }

        // Biggest first, ties broken by the taxonomy's own order so the same
        // store always renders the same way.
        byCategory = Self.ranked(
            CompetitionCategory.allCases.map { category in
                Tally(key: category, count: competitions.count { $0.category == category })
            })
        byRegion = Self.ranked(
            Region.allCases.map { region in
                Tally(key: region, count: competitions.count { $0.region == region })
            })
        bySource = Self.ranked(
            Dictionary(grouping: competitions, by: \.source)
                .map { Tally(key: $0.key, count: $0.value.count) }
                .sorted { $0.key < $1.key })
    }

    /// Descending by count, keeping the incoming order for ties.
    private static func ranked<Key>(_ tallies: [Tally<Key>]) -> [Tally<Key>] {
        tallies.enumerated()
            .sorted {
                $0.element.count == $1.element.count
                    ? $0.offset < $1.offset
                    : $0.element.count > $1.element.count
            }
            .map(\.element)
    }

    /// The largest count in a breakdown, for scaling a bar. Never zero, so a
    /// view can divide by it without guarding.
    public static func scale<Key>(for tallies: [Tally<Key>]) -> Int {
        max(tallies.map(\.count).max() ?? 1, 1)
    }
}
