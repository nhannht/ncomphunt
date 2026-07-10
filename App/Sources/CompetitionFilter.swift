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

/// List sort order, persisted via @AppStorage as its raw value.
enum ListSort: String, CaseIterable, Identifiable {
    case deadline
    case newest
    case title
    case source

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deadline: "Next deadline"
        case .newest: "Newest found"
        case .title: "Title"
        case .source: "Source"
        }
    }

    func areInOrder(_ a: Competition, _ b: Competition) -> Bool {
        switch self {
        case .deadline:
            return (a.nextRelevantDate ?? .distantFuture, a.title)
                < (b.nextRelevantDate ?? .distantFuture, b.title)
        case .newest:
            if a.firstSeen != b.firstSeen { return a.firstSeen > b.firstSeen }
            return a.title < b.title
        case .title:
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        case .source:
            return (a.source, a.title) < (b.source, b.title)
        }
    }
}

/// List grouping, persisted via @AppStorage as its raw value.
enum ListGrouping: String, CaseIterable, Identifiable {
    case none
    case source
    case category
    case region

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .source: "Source"
        case .category: "Category"
        case .region: "Region"
        }
    }

    func key(for competition: Competition) -> String? {
        switch self {
        case .none:
            nil
        case .source:
            SourceID(rawValue: competition.source)?.displayName ?? competition.source
        case .category:
            competition.category.displayName
        case .region:
            competition.region.displayName
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
