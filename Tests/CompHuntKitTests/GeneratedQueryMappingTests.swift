import Foundation
import Testing
@testable import CompHuntKit

/// The model is never invoked here. These tests cover the pure translation from
/// what the model produced to the filter the list applies, which is the part
/// that can be wrong in a way a person would not immediately notice.
private let now = Date(timeIntervalSince1970: 1_000_000_000)
private let day: TimeInterval = 86_400

/// Neutral source sentence: it names no place, so a region the model invented
/// for it is correctly discarded. Tests that care about place pass their own.
private let neutral = "competitions"

private func g(
    categories: [QueryCategory] = [],
    region: QueryRegion = .anywhere,
    eventName: String? = nil,
    withinDays: Int? = nil
) -> GeneratedQuery {
    GeneratedQuery(
        categories: categories, region: region,
        eventName: eventName, withinDays: withinDays)
}

private func map(
    _ generated: GeneratedQuery, from text: String = neutral
) -> SearchQuery {
    SearchQuery(generated, from: text, now: now)
}

@Suite struct EmptyGeneration {
    @Test func producesAnUnconstrainedQuery() {
        #expect(map(g()).isEmpty)
    }
}

@Suite struct CategoryMapping {
    @Test func everyCaseMapsToItsKitCategory() {
        #expect(QueryCategory.competitiveProgramming.kitValue == .cp)
        #expect(QueryCategory.captureTheFlagSecurity.kitValue == .ctf)
        #expect(QueryCategory.artificialIntelligence.kitValue == .ai)
        #expect(QueryCategory.hackathon.kitValue == .hackathon)
        #expect(QueryCategory.design.kitValue == .design)
    }

    @Test func multipleCategoriesSurvive() {
        #expect(map(g(categories: [.artificialIntelligence, .hackathon])).categories
            == [.ai, .hackathon])
    }

    @Test func duplicatesCollapse() {
        #expect(map(g(categories: [.design, .design])).categories == [.design])
    }
}

/// A region is trusted only when the sentence actually names a place.
///
/// Measured, in this order: an optional vietnam/global enum returned a spurious
/// `global` for requests naming no place; rewording the guide moved the failure
/// between phrasings; a required `Bool` came back true for almost everything.
/// The model fills this field whatever shape it is given, so the source text is
/// consulted as ground truth instead of trusting the answer.
@Suite struct RegionMapping {
    @Test func anywhereMeansUnconstrained() {
        #expect(map(g(region: .anywhere)).regions.isEmpty)
    }

    @Test func vietnamIsHonoredWhenThePlaceWasNamed() {
        #expect(map(g(region: .vietnam), from: "AI contests in Vietnam").regions == [.vietnam])
    }

    @Test func internationalIsHonoredWhenAskedFor() {
        #expect(map(g(region: .international), from: "international hackathons").regions == [.global])
    }

    @Test func aRegionIsDiscardedWhenNoPlaceWasMentioned() {
        // The observed failure: "security competitions" came back as
        // international, which would hide every Vietnamese row.
        #expect(map(g(region: .international), from: "security competitions").regions.isEmpty)
        #expect(map(g(region: .vietnam), from: "graphic design work").regions.isEmpty)
    }

    @Test func aVietnameseCityCountsAsNamingAPlace() {
        #expect(map(g(region: .vietnam), from: "contests in Saigon").regions == [.vietnam])
    }
}

/// Free text the model invented ranks; it never gates.
///
/// This is the rule that makes a blank list impossible. An earlier version made
/// the event name a hard constraint, and the model promptly filed "graphic
/// design work" there - a phrase in no competition title - which erased every
/// correctly-matched row. A model-invented string is never a reliable
/// constraint, whatever the field is called.
@Suite struct EventNameBecomesRankingTerms {
    @Test func aBrandNameBecomesTerms() {
        let query = map(g(categories: [.design], eventName: "Zalo"))
        #expect(query.terms == ["Zalo"])
        #expect(query.categories == [.design])
    }

    @Test func aJunkPhraseCannotGate() {
        // It contributes to rank and nothing more, so the design rows survive.
        let query = map(g(categories: [.design], eventName: "graphic design work"))
        #expect(query.categories == [.design])
        #expect(query.terms == ["graphic", "design", "work"])
    }

    @Test func blankIsDropped() {
        #expect(map(g(eventName: "   ")).terms.isEmpty)
    }

    @Test func aCategoryNameFoldsIntoItsAxisInstead() {
        let query = map(g(eventName: "hackathon"))
        #expect(query.categories == [.hackathon])
        #expect(query.terms.isEmpty)
    }

    @Test func aPlaceNameDoesNotBecomeATerm() {
        // Already the region's job. As a term it would rank rows by whether
        // they literally spell "Vietnam" in the title.
        #expect(map(g(eventName: "Vietnam"), from: "contests in Vietnam").terms.isEmpty)
    }
}

@Suite struct TimeframeMapping {
    @Test func absentTimeframeLeavesTheWindowOpen() {
        #expect(map(g()).withinDays == nil)
    }

    @Test func withinDaysSurvivesAsARelativeWindow() {
        // Kept relative rather than resolved to a date pair, so the whole query
        // round-trips through the search field as `deadline:30d` and cannot go
        // stale overnight.
        #expect(map(g(withinDays: 30)).withinDays == 30)
        #expect(map(g(withinDays: 30)).serialized().contains("deadline:30d"))
    }

    @Test func nonPositiveDaysProduceNoWindow() {
        // Rather than an inverted or zero-width window that matches nothing.
        #expect(map(g(withinDays: 0)).withinDays == nil)
        #expect(map(g(withinDays: -5)).withinDays == nil)
    }

    @Test func resolutionIsDeterministicForAFixedNow() {
        #expect(map(g(withinDays: 7)) == map(g(withinDays: 7)))
    }
}

@Suite struct FullSentenceShape {
    @Test func resolvesToEveryAxis() {
        let query = map(
            g(categories: [.artificialIntelligence], region: .vietnam, withinDays: 30),
            from: "AI competitions in Vietnam closing this month")
        #expect(query.categories == [.ai])
        #expect(query.regions == [.vietnam])
        #expect(query.terms.isEmpty)
        #expect(query.withinDays == 30)
        #expect(!query.isEmpty)
    }
}
