import Foundation
import Testing
@testable import CompHuntKit

/// Real titles from the store, because the bug reports were about these exact
/// rows and a synthetic fixture is how the last round of tests passed while the
/// app still returned nothing.
private let openAtlas = "Open Atlas - AI for Social Good Hackathon 2026"
private let openAI = "OpenAI Build Week"
private let spectral = "Spectral::Cup 2026 Round 3"
private let vietnamese = "Cuộc thi Thiết Kế Poster 2026"

@Suite struct TheLadder {
    @Test func exactWordOutranksPrefix() {
        // The reported ordering bug. Under substring containment these were
        // indistinguishable, so OpenAI could outrank the row actually named
        // "Open". Nothing special-cases it now - the ladder does the work.
        let atlas = FuzzyMatch.score(term: "open", in: openAtlas)
        let ai = FuzzyMatch.score(term: "open", in: openAI)
        #expect(atlas == FuzzyMatch.exact)
        #expect(ai == FuzzyMatch.prefix)
        #expect(atlas > ai)
    }

    @Test func prefixMatchesPartialWord() {
        #expect(FuzzyMatch.score(term: "hack", in: openAtlas) == FuzzyMatch.prefix)
    }

    @Test func infixIsWeakerThanPrefix() {
        // "athon" is inside Hackathon but not at its start.
        #expect(FuzzyMatch.score(term: "athon", in: openAtlas) == FuzzyMatch.infix)
    }

    @Test func subsequenceIsTheWeakestRung() {
        #expect(FuzzyMatch.score(term: "hckthn", in: openAtlas) == FuzzyMatch.subsequence)
    }

    @Test func nothingMatchesScoresZero() {
        #expect(FuzzyMatch.score(term: "zzzzzz", in: openAtlas) == 0)
    }

    @Test func punctuationDoesNotHideAWord() {
        // "Spectral::Cup" has to yield the word "cup", or the one competition
        // that answers "cup" stays unreachable.
        #expect(FuzzyMatch.score(term: "cup", in: spectral) == FuzzyMatch.exact)
    }
}

@Suite struct Typos {
    @Test func oneEditIsForgiven() {
        #expect(FuzzyMatch.score(term: "hackaton", in: openAtlas) == FuzzyMatch.nearMiss)
    }

    @Test func transposedLettersAreOneEditNotTwo() {
        // Damerau rather than plain Levenshtein: swapping two adjacent keys is
        // the single most common typing mistake, and plain edit distance
        // charges double for it.
        #expect(FuzzyMatch.score(term: "opne", in: openAtlas) == FuzzyMatch.nearMiss)
    }

    @Test func twoEditsOnlyForLongerTerms() {
        // Two wrong letters in a four-letter word is a different word.
        #expect(FuzzyMatch.editLimit(for: "open") == 1)
        #expect(FuzzyMatch.editLimit(for: "hackathon") == 2)
        #expect(FuzzyMatch.editLimit(for: "cup") == 0)
    }

    @Test func shortTermsStayExact() {
        // At one or two characters edit distance matches nearly everything, so
        // it is switched off rather than producing noise.
        #expect(FuzzyMatch.score(term: "zz", in: "Pizza Contest") == 0)
        #expect(FuzzyMatch.score(term: "ai", in: openAtlas) == FuzzyMatch.exact)
    }

    @Test func distanceRejectsBeyondTheLimit() {
        #expect(FuzzyMatch.boundedDistance("kitten", "sitting", limit: 2) == nil)
        #expect(FuzzyMatch.boundedDistance("kitten", "sitting", limit: 3) == 3)
    }

    @Test func lengthAloneCanReject() {
        // The prefilter, which runs before any allocation.
        #expect(FuzzyMatch.boundedDistance("ab", "abcdefgh", limit: 2) == nil)
    }
}

/// A third of a typical store is Vietnamese, and nobody types tone marks into a
/// search field. Without folding, those rows are unreachable to exactly the
/// people they were collected for.
@Suite struct Diacritics {
    @Test func vietnameseMatchesWithoutToneMarks() {
        #expect(FuzzyMatch.score(term: "thiet", in: vietnamese) == FuzzyMatch.exact)
        #expect(FuzzyMatch.score(term: "ke", in: vietnamese) == FuzzyMatch.exact)
        #expect(FuzzyMatch.score(term: "cuoc", in: vietnamese) == FuzzyMatch.exact)
    }

    @Test func toneMarksStillMatchThemselves() {
        // Folding must not break the person who DOES type them.
        #expect(FuzzyMatch.score(term: "Thiết", in: vietnamese) == FuzzyMatch.exact)
    }

    @Test func caseIsIrrelevant() {
        #expect(FuzzyMatch.score(term: "OPEN", in: openAtlas) == FuzzyMatch.exact)
    }
}

@Suite struct Phrases {
    @Test func literalContainmentIgnoresCaseAndTone() {
        #expect(FuzzyMatch.containsLiterally("open atlas", in: openAtlas))
        #expect(FuzzyMatch.containsLiterally("thiet ke", in: vietnamese))
    }

    @Test func literalContainmentDoesNotForgiveATypo() {
        // The point of quoting: it turns the fuzziness off.
        #expect(!FuzzyMatch.containsLiterally("opne atlas", in: openAtlas))
        #expect(!FuzzyMatch.containsLiterally("open cup", in: openAtlas))
    }

    @Test func adjacencyNeedsTheWordsTouching() {
        #expect(FuzzyMatch.containsAdjacently(["open", "atlas"], in: openAtlas))
        #expect(!FuzzyMatch.containsAdjacently(["open", "hackathon"], in: openAtlas))
    }

    @Test func aSingleTermIsNotAPhrase() {
        #expect(!FuzzyMatch.containsAdjacently(["open"], in: openAtlas))
    }
}
