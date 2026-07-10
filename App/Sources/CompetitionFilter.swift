import CompHuntKit
import Foundation

enum CompetitionFilter: Hashable, Identifiable, CaseIterable {
    case all
    case category(CompetitionCategory)
    case vietnam

    var id: Self { self }

    static var allCases: [CompetitionFilter] {
        [.all]
            + CompetitionCategory.allCases.filter { $0 != .other }.map { .category($0) }
            + [.category(.other), .vietnam]
    }

    var label: String {
        switch self {
        case .all: "All"
        case .category(let category): category.displayName
        case .vietnam: "Vietnam"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .category(.cp): "chevron.left.forwardslash.chevron.right"
        case .category(.ctf): "flag"
        case .category(.ai): "brain"
        case .category(.hackathon): "hammer"
        case .category(.design): "paintbrush"
        case .category(.other): "questionmark.circle"
        case .vietnam: "mappin.and.ellipse"
        }
    }

    func matches(_ competition: Competition) -> Bool {
        switch self {
        case .all: true
        case .category(let category): competition.category == category
        case .vietnam: competition.region == .vietnam
        }
    }
}

extension Competition {
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

    func isNew(asOf now: Date = .now) -> Bool {
        firstSeen.distance(to: now) < 24 * 3600
    }
}
