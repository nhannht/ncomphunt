import CompHuntKit
import Foundation

/// Sidebar selection: the category axis only. Region is an orthogonal concern
/// handled by `RegionFilter`, not another entry in this list.
enum CompetitionFilter: Hashable, Identifiable, CaseIterable {
    case all
    case category(CompetitionCategory)

    var id: Self { self }

    static var allCases: [CompetitionFilter] {
        [.all]
            + CompetitionCategory.allCases.filter { $0 != .other }.map { .category($0) }
            + [.category(.other)]
    }

    var label: String {
        switch self {
        case .all: "All"
        case .category(let category): category.displayName
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
        }
    }

    func matches(_ competition: Competition) -> Bool {
        switch self {
        case .all: true
        case .category(let category): competition.category == category
        }
    }
}

/// Region filter, orthogonal to the category sidebar. Persisted via @AppStorage
/// as its raw value; the toolbar filter menu and the list read the same truth.
enum RegionFilter: String, CaseIterable, Identifiable {
    case all
    case vietnam
    case global

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All regions"
        case .vietnam: "Vietnam"
        case .global: "Global"
        }
    }

    /// True when a region other than "all" is active, so the toolbar icon can
    /// signal that the list is filtered.
    var isActive: Bool { self != .all }

    func matches(_ competition: Competition) -> Bool {
        switch self {
        case .all: true
        case .vietnam: competition.region == .vietnam
        case .global: competition.region == .global
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
    /// `nextRelevantDate` and `isCurrent(asOf:)` now live in CompHuntKit
    /// (Schedule.swift) so the selection logic is unit-testable without the app.
    func isNew(asOf now: Date = .now) -> Bool {
        firstSeen.distance(to: now) < 24 * 3600
    }
}

/// RawRepresentable so the category filter can persist via `@AppStorage`, letting
/// the main window and the menu-bar countdown read one shared truth.
extension CompetitionFilter: RawRepresentable {
    init?(rawValue: String) {
        if rawValue == "all" {
            self = .all
        } else if let category = CompetitionCategory(rawValue: rawValue) {
            self = .category(category)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .all: "all"
        case .category(let category): category.rawValue
        }
    }

    /// nil means "any category" - the input `nextUpcoming` expects.
    var categoryValue: CompetitionCategory? {
        switch self {
        case .all: nil
        case .category(let category): category
        }
    }
}

extension RegionFilter {
    /// nil means "any region" - the input `nextUpcoming` expects.
    var regionValue: Region? {
        switch self {
        case .all: nil
        case .vietnam: .vietnam
        case .global: .global
        }
    }
}
