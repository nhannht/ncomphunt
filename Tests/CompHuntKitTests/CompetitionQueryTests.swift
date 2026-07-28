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
    deadline: Date? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: "test", title: title, organizer: organizer,
        url: "https://example.com/\(title)", registrationDeadline: deadline)
    return Competition(dto: dto, category: category, region: region)
}

@Suite struct EmptyQuery {
    @Test func matchesEverything() {
        let query = CompetitionQuery()
        #expect(query.isEmpty)
        #expect(query.matches(comp("anything")))
        #expect(query.matches(comp("other", category: .design, region: .vietnam)))
    }

    @Test func blankTermDoesNotConstrain() {
        // The search field hands over tokenized text; empty text must not filter.
        let query = CompetitionQuery(terms: CompetitionQuery.tokenize("   "))
        #expect(query.isEmpty)
        #expect(query.matches(comp("anything")))
    }

    @Test func scoreIsZeroWhenNoTextWasTyped() {
        #expect(CompetitionQuery().score(comp("anything")) == 0)
    }
}

@Suite struct CategoryAxis {
    @Test func emptySetMeansAny() {
        #expect(CompetitionQuery().matches(comp("x", category: .ai)))
    }

    @Test func singleCategoryNarrows() {
        let query = CompetitionQuery(categories: [.ai])
        #expect(query.matches(comp("x", category: .ai)))
        #expect(!query.matches(comp("y", category: .ctf)))
    }

    @Test func multipleCategoriesAreUnioned() {
        // Only a generated query produces more than one; the sidebar cannot.
        let query = CompetitionQuery(categories: [.ai, .hackathon])
        #expect(query.matches(comp("a", category: .ai)))
        #expect(query.matches(comp("h", category: .hackathon)))
        #expect(!query.matches(comp("c", category: .cp)))
    }
}

@Suite struct RegionAxis {
    @Test func nilMeansAny() {
        let query = CompetitionQuery()
        #expect(query.matches(comp("v", region: .vietnam)))
        #expect(query.matches(comp("g", region: .global)))
    }

    @Test func setRegionNarrows() {
        let query = CompetitionQuery(region: .vietnam)
        #expect(query.matches(comp("v", region: .vietnam)))
        #expect(!query.matches(comp("g", region: .global)))
    }
}

/// Free text ranks rather than gates. This REPLACES the old whole-phrase
/// substring behavior, deliberately: under the old rule a single term nothing
/// happened to contain removed every correctly-matched row, which is how a
/// filter that found 28 design contests could still show a blank list.
@Suite struct TermRanking {
    private func query(_ text: String) -> CompetitionQuery {
        CompetitionQuery(terms: CompetitionQuery.tokenize(text))
    }

    @Test func scatteredWordsNowMatch() {
        // Behavior change, on purpose: "Open Championship Cup" carries both
        // words apart. The old single-substring test rejected it.
        #expect(query("open cup").matches(comp("Open Championship Cup")))
    }

    @Test func adjacentPhraseOutranksScattered() {
        let q = query("open cup")
        let adjacent = q.score(comp("Codeforces Open Cup Stage 3"))
        let scattered = q.score(comp("Open Championship Cup"))
        #expect(adjacent != nil && scattered != nil)
        #expect(adjacent! > scattered!)
    }

    @Test func titleBeatsOrganizer() {
        let q = query("vnoi")
        #expect(q.score(comp("VNOI Cup"))! > q.score(comp("Round 5", organizer: "VNOI"))!)
    }

    @Test func matchesTitleOrOrganizer() {
        let q = query("vnoi")
        #expect(q.matches(comp("Round 5", organizer: "VNOI")))
        #expect(q.matches(comp("VNOI Cup", organizer: "Someone")))
        #expect(!q.matches(comp("Round 5", organizer: "Codeforces")))
    }

    @Test func caseInsensitive() {
        #expect(query("CTF").matches(comp("picoctf 2026")))
    }

    @Test func partialMatchSurvivesInsteadOfBlanking() {
        // The whole point. "work" appears in no title, and under the old ANDed
        // rule it erased the result. Now it simply contributes nothing.
        let q = query("design work")
        #expect(q.matches(comp("Poster Design Award")))
    }

    @Test func moreMatchedTermsRanksHigher() {
        let q = query("vnoi cup")
        #expect(q.score(comp("VNOI Cup"))! > q.score(comp("World Cup"))!)
    }

    @Test func nothingMatchedIsExcludedNotRankedLast() {
        // A row matching no term is wrong, not merely weak.
        #expect(query("zzzz").score(comp("VNOI Cup")) == nil)
    }
}

/// Every gating axis is a closed set, so no filter can ever be unsatisfiable
/// by construction. This is the invariant that makes a blank list impossible.
@Suite struct GatingAxesAreClosedSets {
    @Test func aWrongGuessNarrowsButNeverBlanks() {
        // Worst case for a generated filter: every axis guessed wrongly. Each
        // still names a real category and a real region, so some row somewhere
        // satisfies it. Contrast a free-text gate, where an invented phrase
        // matches nothing at all.
        let q = CompetitionQuery(categories: [.design], region: .vietnam)
        #expect(q.matches(comp("x", category: .design, region: .vietnam)))
    }
}

@Suite struct DeadlineWindow {
    @Test func boundsAreInclusive() {
        let query = CompetitionQuery(
            deadlineAfter: now, deadlineBefore: now.addingTimeInterval(7 * day))
        #expect(query.matches(comp("onLower", deadline: now)))
        #expect(query.matches(comp("onUpper", deadline: now.addingTimeInterval(7 * day))))
    }

    @Test func excludesOutsideTheWindow() {
        let query = CompetitionQuery(
            deadlineAfter: now, deadlineBefore: now.addingTimeInterval(7 * day))
        #expect(!query.matches(comp("early", deadline: now.addingTimeInterval(-day))))
        #expect(!query.matches(comp("late", deadline: now.addingTimeInterval(30 * day))))
    }

    @Test func datelessRowsFailAnActiveWindow() {
        // A row with no date cannot honestly satisfy "closing this month".
        let query = CompetitionQuery(deadlineBefore: now.addingTimeInterval(30 * day))
        #expect(!query.matches(comp("dateless")))
    }

    @Test func datelessRowsSurviveWhenNoWindowIsSet() {
        #expect(CompetitionQuery(categories: [.ctf]).matches(comp("dateless")))
    }
}

@Suite struct AxesCombine {
    @Test func everyConstrainedAxisMustHold() {
        let query = CompetitionQuery(
            categories: [.ai], region: .vietnam,
            deadlineBefore: now.addingTimeInterval(30 * day))
        let hit = comp("Zalo AI Challenge", category: .ai, region: .vietnam,
                       deadline: now.addingTimeInterval(day))
        #expect(query.matches(hit))
        // One constrained axis wrong is enough to reject.
        #expect(!query.matches(comp("Zalo AI Challenge", category: .ai, region: .global,
                                    deadline: now.addingTimeInterval(day))))
        #expect(!query.matches(comp("Zalo AI Challenge", category: .design, region: .vietnam,
                                    deadline: now.addingTimeInterval(day))))
        #expect(!query.matches(comp("Zalo AI Challenge", category: .ai, region: .vietnam,
                                    deadline: now.addingTimeInterval(90 * day))))
    }

    @Test func termsRankWithinTheConstrainedSetAndNeverEmptyIt() {
        // Constraints hold; the text only orders what survives them. A term
        // matching nothing still leaves the constrained rows visible via the
        // terms that did match.
        let query = CompetitionQuery(
            categories: [.ai], terms: CompetitionQuery.tokenize("zalo unmatchableword"))
        let named = comp("Zalo AI Challenge", category: .ai)
        #expect(query.matches(named))
        // Wrong category is still rejected: a preference cannot rescue a
        // failed constraint.
        #expect(!query.matches(comp("Zalo Design Award", category: .design)))
    }
}
