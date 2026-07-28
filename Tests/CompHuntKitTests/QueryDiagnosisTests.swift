import Foundation
import Testing
@testable import CompHuntKit

private let now = Date(timeIntervalSince1970: 1_000_000_000)
private let day: TimeInterval = 86_400

private func comp(
    _ title: String,
    organizer: String = "",
    category: CompetitionCategory = .ctf,
    region: Region = .global,
    source: String = "ctftime",
    deadline: Date? = nil,
    end: Date? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: source, title: title, organizer: organizer,
        url: "https://example.com/\(title)",
        endDate: end, registrationDeadline: deadline)
    return Competition(dto: dto, category: category, region: region)
}

/// A query can carry several constraints at once, and a person has no way to
/// tell which is expensive: a category holding one current competition looks
/// exactly like a category holding forty.
@Suite struct NarrowestConstraint {
    /// Shaped like the real store: plenty of CTF and AI, one current CP row,
    /// and the words only appearing outside the CP category.
    private var index: [Competition] {
        var rows = (1...12).map { comp("CTF Event \($0)", category: .ctf) }
        rows += (1...8).map { comp("AI Contest \($0)", category: .ai) }
        rows.append(comp("Codeforces Round 1109", category: .cp, source: "codeforces"))
        rows.append(comp("Open Atlas - AI for Social Good Hackathon 2026",
                         category: .hackathon, source: "devpost"))
        rows.append(comp("OpenAI Build Week", category: .ai, source: "mlcontests"))
        return rows
    }

    @Test func typingCanNoLongerEmptyTheList() {
        // The reported case, under the new rules. "open cup" scoped to
        // Competitive Programming used to show nothing at all; the words match
        // no CP row, and every word was a gate. Now the category admits its one
        // row and the words merely fail to rank it, so there is a result and
        // nothing to diagnose.
        let query = SearchQuery.parse("category:cp open cup")
        #expect(query.matchCount(in: index, now: now) == 1)
        #expect(query.narrowestConstraint(in: index, now: now) == nil)
    }

    @Test func namesTheCategoryHoldingNothing() {
        // So reaching an empty list now always means an operator did it - which
        // is exactly when naming the expensive one pays. Terms are absent from
        // the diagnosis entirely, because removing one could never reveal a row.
        let query = SearchQuery.parse("category:design open cup")
        #expect(query.matchCount(in: index, now: now) == 0)

        let diagnosis = query.narrowestConstraint(in: index, now: now)
        #expect(diagnosis?.axis == .category(.design))
        #expect(diagnosis?.countWithout == 2)   // the two rows carrying the words
    }

    @Test func picksTheAxisThatRevealsTheMost() {
        let query = SearchQuery.parse("category:cp region:vietnam")
        let diagnosis = query.narrowestConstraint(in: index, now: now)
        // Every row is global, so region is the one hiding everything.
        #expect(diagnosis?.axis == .region(.vietnam))
        #expect(diagnosis?.countWithout == 1)
    }

    @Test func aSourceCanBeTheExpensiveOne() {
        let query = SearchQuery.parse("category:ctf source:devpost")
        let diagnosis = query.narrowestConstraint(in: index, now: now)
        #expect(diagnosis?.axis == .source(.devpost))
        #expect(diagnosis?.countWithout == 12)
    }

    @Test func aQuotedPhraseCanBeTheExpensiveOne() {
        // Under the new rules a phrase is one of only two ways to reach an
        // empty list, which is exactly why it has to be diagnosable.
        let query = SearchQuery.parse("category:ctf \"open cup\"")
        let diagnosis = query.narrowestConstraint(in: index, now: now)
        #expect(diagnosis?.axis == .phrase("open cup"))
        #expect(diagnosis?.countWithout == 12)
    }

    @Test func aDeadlineWindowCanBeTheExpensiveOne() {
        let rows = [comp("Soon", category: .ctf, deadline: now.addingTimeInterval(60 * day))]
        let query = SearchQuery.parse("category:ctf deadline:week")
        let diagnosis = query.narrowestConstraint(in: rows, now: now)
        #expect(diagnosis?.axis == .deadline)
        #expect(diagnosis?.countWithout == 1)
    }

    @Test func staysSilentWhenNoSingleRemovalHelps() {
        // Jointly unsatisfiable. Naming one axis would promise results that
        // removing it does not produce.
        let query = SearchQuery.parse("category:design \"unmatchable phrase\"")
        #expect(query.narrowestConstraint(in: index, now: now) == nil)
    }

    @Test func silentWhenNothingWouldHelp() {
        let query = SearchQuery.parse("category:ctf")
        #expect(query.narrowestConstraint(in: [], now: now) == nil)
    }

    @Test func silentWhenTheListIsAlreadyFull() {
        #expect(SearchQuery().narrowestConstraint(in: index, now: now) == nil)
    }
}

/// Finished competitions are shown only to someone who is searching, and only
/// when the row answers what they typed.
@Suite struct EndedVisibility {
    private var spectral: Competition {
        comp("Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)", category: .cp, source: "codeforces",
             end: now.addingTimeInterval(-12 * day))
    }
    private var live: Competition { comp("CTF Event", category: .ctf) }
    private var index: [Competition] { [spectral, live] }

    private func shown(_ text: String) -> [String] {
        SearchQuery.parse(text)
            .results(from: index, now: now, tieBreak: { $0.title < $1.title })
            .items.map(\.title)
    }

    @Test func browsingHidesFinishedCompetitions() {
        // A sidebar click produces exactly this query, and browsing is not
        // searching, so it stays free of rows that already closed.
        #expect(shown("category:cp").isEmpty)
    }

    @Test func searchingRevealsAFinishedMatch() {
        // The real cause of the reported blank screen: the only row carrying
        // the word had ended, so it was hidden and the person was told nothing
        // matched.
        #expect(shown("cup") == [spectral.title])
    }

    @Test func searchingDoesNotDragInEveryFinishedRow() {
        // The ended row does not answer this, so it stays out even though the
        // search itself found nothing and fell back.
        #expect(shown("hackathon") == [live.title])
    }

    @Test func liveRowsSurviveAWordThatMatchesNothing() {
        #expect(shown("zzzzzz") == [live.title])
        #expect(shown("") == [live.title])
    }
}

@Suite struct AxisRemoval {
    @Test func eachAxisRemovesOnlyItself() {
        var query = SearchQuery.parse(
            "category:ctf category:ai region:vietnam source:ybox deadline:week \"a b\"")

        query.remove(.category(.ctf))
        #expect(query.categories == [.ai])

        query.remove(.region(.vietnam))
        #expect(query.regions.isEmpty)

        query.remove(.source(.ybox))
        #expect(query.sources.isEmpty)

        query.remove(.deadline)
        #expect(query.withinDays == nil)

        query.remove(.phrase("a b"))
        #expect(query.phrases.isEmpty)
    }

    @Test func termsAreNotAnAxis() {
        // They rank rather than filter, so there is nothing to remove.
        #expect(SearchQuery.parse("open cup").activeAxes.isEmpty)
    }

    @Test func anEmptyQueryHasNoAxes() {
        #expect(SearchQuery().activeAxes.isEmpty)
    }
}

@Suite struct DeadlineWindow {
    @Test func namedSpansParse() {
        #expect(SearchQuery.parse("deadline:week").withinDays == 7)
        #expect(SearchQuery.parse("deadline:month").withinDays == 30)
        #expect(SearchQuery.parse("deadline:30d").withinDays == 30)
        #expect(SearchQuery.parse("deadline:14").withinDays == 14)
    }

    @Test func theNarrowestWindowWins() {
        #expect(SearchQuery.parse("deadline:month deadline:week").withinDays == 7)
    }

    @Test func aDatelessRowFailsAnActiveWindow() {
        let query = SearchQuery.parse("deadline:month")
        #expect(!query.admits(comp("dateless"), now: now))
    }

    @Test func onlyDatesInsideTheWindowSurvive() {
        let query = SearchQuery.parse("deadline:week")
        #expect(query.admits(comp("soon", deadline: now.addingTimeInterval(3 * day)), now: now))
        #expect(!query.admits(comp("later", deadline: now.addingTimeInterval(30 * day)), now: now))
    }

    @Test func anUnparseableWindowBecomesATerm() {
        let query = SearchQuery.parse("deadline:someday")
        #expect(query.withinDays == nil)
        #expect(query.terms == ["someday"])
    }
}
