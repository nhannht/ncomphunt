import Foundation
import Testing
@testable import CompHuntKit

private let now = Date(timeIntervalSince1970: 1_000_000_000)
private let day: TimeInterval = 86_400

private func comp(
    _ title: String,
    category: CompetitionCategory = .ctf,
    region: Region = .global,
    source: String = "ctftime",
    end: Date? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: source, title: title, organizer: "",
        url: "https://example.com/\(title)", endDate: end)
    return Competition(dto: dto, category: category, region: region)
}

/// The three rows the reported query should have found, with the dates the
/// store actually holds: Open Atlas runs to August, OpenAI Build Week carries
/// no dates at all, and Spectral::Cup closed twelve days ago.
private var store: [Competition] {
    [
        comp("Open Atlas - AI for Social Good Hackathon 2026",
             category: .hackathon, source: "devpost",
             end: now.addingTimeInterval(22 * day)),
        comp("OpenAI Build Week", category: .ai, source: "devpost"),
        comp("Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)",
             category: .cp, source: "codeforces", end: now.addingTimeInterval(-12 * day)),
        comp("picoCTF 2026", category: .ctf),
        comp("Cuộc thi Thiết Kế Poster 2026", category: .design,
             region: .vietnam, source: "ybox"),
    ]
}

private func found(_ text: String) -> SearchResults {
    SearchQuery.parse(text)
        .results(from: store, now: now, tieBreak: { $0.title < $1.title })
}

private func titles(_ text: String) -> [String] { found(text).items.map(\.title) }

/// The reported failure, end to end. `open cup` returned nothing, twice.
@Suite struct TheReportedQuery {
    @Test func findsAllThreeAnswersInOrder() {
        #expect(titles("open cup") == [
            "Open Atlas - AI for Social Good Hackathon 2026",   // "Open", exact
            "OpenAI Build Week",                                // "open", prefix
            "Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)",
        ])
    }

    @Test func theTypoFindsTheSameThree() {
        #expect(titles("opne cup") == titles("open cup"))
    }

    @Test func theEndedRowIsLastDespiteMatchingExactly() {
        // Spectral::Cup answers "cup" as exactly as Open Atlas answers "open",
        // and still sorts below it. That is the separate key doing its job.
        let ranked = titles("cup")
        #expect(ranked.last?.hasPrefix("Spectral") == true)
        #expect(ranked.count == 1)
    }
}

/// Words find things, and failing to find anything still never blanks the
/// screen. Both halves matter: returning the whole index ranked would satisfy
/// "never empty" while making the search box useless.
@Suite struct NeverEmpty {
    @Test func aWordMatchingNothingFallsBackToEverythingCurrent() {
        let results = found("zzzzzz")
        #expect(results.items.count == 4)
        // And says so, or the person is left wondering why a search for
        // nonsense returned the whole list.
        #expect(results.isFallback)
    }

    @Test func matchingAnyTermIsEnoughToBeFound() {
        // The actual fix for the reported bug: OR, not AND. Every row carrying
        // either word appears, and rows carrying neither do not.
        #expect(titles("open cup").count == 3)
        #expect(!found("open cup").isFallback)
    }

    @Test func browsingIsNotAFailedSearch() {
        // No text was typed, so nothing failed to match and nothing is reported.
        #expect(!found("").isFallback)
        #expect(!found("category:ctf").isFallback)
    }

    @Test func onlyOperatorsAndQuotesCanEmptyIt() {
        #expect(titles("category:design region:global").isEmpty)
        #expect(titles("\"open cup\"").isEmpty)
    }

    @Test func aPhraseMatchingOnlyAnEndedRowStillShowsIt() {
        // A phrase is a literal match and needs no score to prove it. Requiring
        // one would blank the list here and then blame the phrase that was right.
        #expect(titles("\"spectral::cup\"") == [
            "Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)",
        ])
    }
}

@Suite struct BrowsingVersusSearching {
    @Test func browsingShowsOnlyLiveRows() {
        // A sidebar click. The ended CP row must not appear.
        #expect(titles("category:cp").isEmpty)
        #expect(titles("").count == 4)
    }

    @Test func searchingSurfacesTheEndedRow() {
        #expect(titles("spectral") == [
            "Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)",
        ])
    }
}

@Suite struct VietnameseWithoutToneMarks {
    @Test func theYboxRowIsReachable() {
        // A third of the real store looks like this row, and none of it was
        // findable before folding.
        #expect(titles("thiet ke").first == "Cuộc thi Thiết Kế Poster 2026")
        #expect(titles("poster").first == "Cuộc thi Thiết Kế Poster 2026")
    }

    @Test func theRegionOperatorFindsIt() {
        #expect(titles("region:vietnam") == ["Cuộc thi Thiết Kế Poster 2026"])
    }
}

@Suite struct OperatorsAndTextCombine {
    @Test func anOperatorNarrowsAndTextOrders() {
        #expect(titles("category:ai open") == ["OpenAI Build Week"])
    }

    @Test func aSourceOperatorFilters() {
        #expect(titles("source:devpost").count == 2)
    }

    @Test func textCannotRescueAFailedOperator() {
        // The words match nothing inside Design, so the fallback shows what
        // Design does hold. The operator still governs: no hackathon appears.
        let results = found("category:design open cup")
        #expect(results.items.map(\.title) == ["Cuộc thi Thiết Kế Poster 2026"])
        #expect(results.isFallback)
    }
}
