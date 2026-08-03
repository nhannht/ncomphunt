import AppIntents
import CompHuntKit
import CoreSpotlight
import Foundation

/// One competition as the system sees it: Siri resolution, Spotlight results,
/// Shortcuts values, and (on macOS 26) the Shortcuts "Use Model" action all
/// read this. A value snapshot of the SwiftData row - entities cross process
/// and actor boundaries, so they cannot carry the live model object.
///
/// Exposes only what the app already stores (COMP-24's no-new-data rule).
struct CompetitionEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Competition"
    static let defaultQuery = CompetitionQuery()

    /// The dedupe key - already the app-wide identity for deep links,
    /// reminders, and the Live Activity, so Spotlight taps and intent results
    /// route through the same door.
    let id: String

    @Property(title: "Title")
    var title: String

    @Property(title: "Category")
    var category: String

    @Property(title: "Region")
    var region: String

    @Property(title: "Prize")
    var prize: String?

    /// The row's one relative phrase ("due in 2 days"), from the kit's
    /// `whenLine` so every surface words a date the same way.
    @Property(title: "When")
    var when: String

    @Property(title: "Date")
    var date: Date?

    @Property(title: "URL")
    var url: URL?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(category) · \(when)")
    }

    @MainActor
    init(_ competition: Competition) {
        id = competition.key
        title = competition.title
        category = competition.category.displayName
        region = competition.region.displayName
        prize = competition.prize.isEmpty ? nil : competition.prize
        when = competition.whenLine
        date = competition.nextRelevantDate
        url = URL(string: competition.url)
    }
}

/// Resolves competitions for Siri, Spotlight, and Shortcuts. Reads through the
/// one `AppModel` (registered with `AppDependencyManager` at scene init) - a
/// second `ModelContainer` on the same store file would be a parallel path.
struct CompetitionQuery: EntityQuery, EntityStringQuery {
    @Dependency private var model: AppModel

    @MainActor
    func entities(for identifiers: [String]) async throws -> [CompetitionEntity] {
        identifiers.compactMap { key in
            model.competition(forKey: key).map(CompetitionEntity.init)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [CompetitionEntity] {
        model.allCompetitions()
            .filter { $0.title.localizedCaseInsensitiveContains(string) }
            .prefix(20)
            .map(CompetitionEntity.init)
    }

    /// What Shortcuts offers before the user types: the next deadlines,
    /// soonest first - the same order every other surface leads with.
    @MainActor
    func suggestedEntities() async throws -> [CompetitionEntity] {
        upcomingContests(in: model.allCompetitions(), category: nil, region: nil,
                         limit: 10)
            .map(CompetitionEntity.init)
    }
}
