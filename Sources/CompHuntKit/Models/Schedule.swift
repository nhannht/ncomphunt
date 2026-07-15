import Foundation

/// Scheduling helpers shared by the list, the menu bar, and their tests.
/// Kept in the kit (not the app) so the selection and formatting logic is pure
/// and unit-testable without launching the SwiftUI app.

public extension Competition {
    /// The next date that matters: registration deadline first, then start, then end.
    var nextRelevantDate: Date? {
        registrationDeadline ?? startDate ?? endDate
    }

    /// Upcoming, ongoing, or dateless. Ended competitions drop out of the list.
    func isCurrent(asOf now: Date = .now) -> Bool {
        if let end = endDate { return end >= now }
        if let next = nextRelevantDate { return next >= now }
        return true
    }
}

public extension CompetitionCategory {
    /// Compact code for tight surfaces like the menu-bar countdown label.
    /// `.other` has no code (the label falls back to the countdown alone).
    var shortCode: String {
        switch self {
        case .cp: "CP"
        case .ctf: "CTF"
        case .ai: "AI"
        case .hackathon: "Hack"
        case .design: "Design"
        case .other: ""
        }
    }
}

/// Competitions with a FUTURE relevant date, soonest first, optionally narrowed
/// to a category and/or region (nil means "any") and capped at `limit`. Rows that
/// are ongoing or dateless are excluded because there is nothing to count down to.
/// Ties break on the earlier date; equal dates keep an arbitrary order.
public func upcomingContests(
    in competitions: [Competition],
    category: CompetitionCategory?,
    region: Region?,
    limit: Int? = nil,
    now: Date = .now
) -> [Competition] {
    let sorted = competitions
        .filter { competition in
            guard competition.isCurrent(asOf: now) else { return false }
            if let category, competition.category != category { return false }
            if let region, competition.region != region { return false }
            guard let next = competition.nextRelevantDate, next >= now else { return false }
            return true
        }
        .sorted { ($0.nextRelevantDate ?? .distantFuture) < ($1.nextRelevantDate ?? .distantFuture) }
    guard let limit else { return sorted }
    return Array(sorted.prefix(limit))
}

/// The soonest upcoming competition matching the filters, or nil. The countdown
/// target for the menu bar; `upcomingContests(...).first`.
public func nextUpcoming(
    in competitions: [Competition],
    category: CompetitionCategory?,
    region: Region?,
    now: Date = .now
) -> Competition? {
    upcomingContests(in: competitions, category: category, region: region, limit: 1, now: now).first
}

/// Compact countdown from `now` to `target`, sized for the menu bar: "2h14m",
/// "3d4h", "3d", "45m". Under a minute reads "<1m"; a past target also reads
/// "<1m" (callers filter past targets out before formatting). Formatted by hand
/// rather than via `Duration.formatted` to guarantee this exact, space-free,
/// locale-stable shape at most two units wide.
public func compactCountdown(to target: Date, now: Date = .now) -> String {
    let total = Int(target.timeIntervalSince(now))
    guard total >= 60 else { return "<1m" }
    let days = total / 86_400
    let hours = (total % 86_400) / 3_600
    let minutes = (total % 3_600) / 60
    if days > 0 { return hours > 0 ? "\(days)d\(hours)h" : "\(days)d" }
    if hours > 0 { return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h" }
    return "\(minutes)m"
}
