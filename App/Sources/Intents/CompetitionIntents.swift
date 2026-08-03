import AppIntents
import CompHuntKit
import Foundation

/// "When is my next CTF" - the headline query (COMP-24). Thin skins over the
/// kit's `nextUpcoming` / `upcomingContests`, which every other surface
/// already leads with, so Siri can never rank differently than the menu bar.
struct NextCompetitionIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Competition"
    static let description = IntentDescription(
        "The next upcoming competition, soonest deadline first, optionally narrowed to one category.")

    @Parameter(title: "Category")
    var category: CategoryOption?

    static var parameterSummary: some ParameterSummary {
        Summary("Get the next \(\.$category) competition")
    }

    @Dependency private var model: AppModel

    @MainActor
    func perform() async throws
        -> some IntentResult & ReturnsValue<CompetitionEntity?> & ProvidesDialog {
        let next = nextUpcoming(in: model.allCompetitions(),
                                category: category?.categoryValue, region: nil)
        guard let next else {
            let scope = category.map { " \($0.categoryValue.displayName)" } ?? ""
            return .result(value: nil,
                           dialog: "No upcoming\(scope) competitions.")
        }
        // `whenLine` words the date exactly as the list row does.
        return .result(value: CompetitionEntity(next),
                       dialog: "\(next.title), \(next.whenLine).")
    }
}

/// The list feed for Shortcuts - and, on macOS 26, for the "Use Model" action,
/// which lets people pipe the index through Apple Intelligence in automations
/// we never wrote. Returns entities, not prose, for exactly that reason.
struct UpcomingCompetitionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Upcoming Competitions"
    static let description = IntentDescription(
        "Upcoming competitions soonest first, for Shortcuts to filter, summarise, or automate with.")

    @Parameter(title: "Category")
    var category: CategoryOption?

    @Parameter(title: "Limit", default: 10, inclusiveRange: (1, 50))
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get upcoming \(\.$category) competitions") {
            \.$limit
        }
    }

    @Dependency private var model: AppModel

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[CompetitionEntity]> {
        let rows = upcomingContests(in: model.allCompetitions(),
                                    category: category?.categoryValue, region: nil,
                                    limit: limit)
        return .result(value: rows.map(CompetitionEntity.init))
    }
}

/// What a tapped Spotlight result (and a Shortcuts "Open" action) runs. The
/// deep link is the same `ncomphunt://open?key=` every other surface uses, so
/// opening from Spotlight and tapping a widget row are one code path.
struct OpenCompetitionIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Competition"

    @Parameter(title: "Competition", requestValueDialog: "Which competition?")
    var target: CompetitionEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(competitionDeepLink(key: target.id)))
    }
}
