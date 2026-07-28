import Foundation
import Testing
@testable import CompHuntKit

@Suite struct Suggestions {
    @Test func nothingIsOfferedForAnEmptyField() {
        #expect(SearchQuery.suggestions(for: "").isEmpty)
        #expect(SearchQuery.suggestions(for: "open ").isEmpty)
    }

    @Test func aBareWordOffersTheOperatorsItCouldStart() {
        let offered = SearchQuery.suggestions(for: "cat").map(\.label)
        #expect(offered == ["category:"])
    }

    @Test func aWordThatStartsNoOperatorOffersNothing() {
        // Someone typing "open" is searching, not filtering. A dropdown of
        // every category would be in the way.
        #expect(SearchQuery.suggestions(for: "open").isEmpty)
    }

    @Test func aFieldWithNoValueOffersEveryValue() {
        let offered = SearchQuery.suggestions(for: "category:")
        #expect(offered.count == CompetitionCategory.allCases.count)
        #expect(offered.map(\.label).contains("Hackathon"))
    }

    @Test func aPartialValueNarrows() {
        let offered = SearchQuery.suggestions(for: "category:hack").map(\.label)
        #expect(offered == ["Hackathon"])
    }

    @Test func aMisspeltValueStillAppears() {
        // The dropdown must never omit something the parser would accept.
        let offered = SearchQuery.suggestions(for: "category:hackaton").map(\.label)
        #expect(offered == ["Hackathon"])
    }

    @Test func valuesMatchOnTheirDisplayNameToo() {
        let offered = SearchQuery.suggestions(for: "source:ctftime").map(\.label)
        #expect(offered.contains("CTFtime"))
    }

    @Test func choosingReplacesOnlyTheTrailingToken() {
        // Everything already settled is carried through untouched.
        let offered = SearchQuery.suggestions(for: "region:vietnam open category:hack")
        #expect(offered.first?.completion == "region:vietnam open category:hackathon ")
    }

    @Test func completionsReparseToWhatWasChosen() {
        for suggestion in SearchQuery.suggestions(for: "category:") {
            let query = SearchQuery.parse(suggestion.completion)
            #expect(query.categories.count == 1)
        }
    }

    @Test func deadlineOffersNamedWindows() {
        let offered = SearchQuery.suggestions(for: "deadline:")
        #expect(offered.contains { $0.label == "Within 7 days" })
        #expect(SearchQuery.parse(offered[0].completion).withinDays != nil)
    }

    @Test func nothingIsOfferedInsideAQuote() {
        #expect(SearchQuery.suggestions(for: "\"open cu").isEmpty)
    }
}
