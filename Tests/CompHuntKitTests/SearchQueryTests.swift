import Foundation
import Testing
@testable import CompHuntKit

private func comp(
    _ title: String,
    organizer: String = "",
    category: CompetitionCategory = .ctf,
    region: Region = .global,
    source: String = "ctftime"
) -> Competition {
    let dto = CompetitionDTO(
        source: source, title: title, organizer: organizer,
        url: "https://example.com/\(title)")
    return Competition(dto: dto, tags: category == .other ? [] : [category], region: region)
}

// The three rows the reported query should have found. Computed rather than
// stored because Competition is a SwiftData model and not Sendable.
private var openAtlas: Competition {
    comp("Open Atlas - AI for Social Good Hackathon 2026",
         category: .hackathon, source: "devpost")
}
private var openAI: Competition {
    comp("OpenAI Build Week", category: .ai, source: "mlcontests")
}
private var spectral: Competition {
    comp("Spectral::Cup 2026 Round 3 (Codeforces Round 1110, Div. 1 + Div. 2)", category: .cp, source: "codeforces")
}

@Suite struct Parsing {
    @Test func bareWordsBecomeTerms() {
        let query = SearchQuery.parse("open cup")
        #expect(query.terms == ["open", "cup"])
        #expect(query.categories.isEmpty)
    }

    @Test func operatorsFilter() {
        let query = SearchQuery.parse("category:ctf region:vietnam source:ctftime")
        #expect(query.categories == [.ctf])
        #expect(query.regions == [.vietnam])
        #expect(query.sources == [.ctftime])
        #expect(query.terms.isEmpty)
    }

    @Test func repeatedFieldWidens() {
        // OR within a field, AND across fields - the Discord and GitHub rule.
        let query = SearchQuery.parse("category:ctf category:ai")
        #expect(query.categories == [.ctf, .ai])
    }

    @Test func quotedRunsBecomePhrases() {
        let query = SearchQuery.parse("\"open cup\" hackathon")
        #expect(query.phrases == ["open cup"])
        #expect(query.terms == ["hackathon"])
    }

    @Test func aQuotedPhraseMayContainAColon() {
        // Would be mistaken for an operator if the closing quote decided.
        let query = SearchQuery.parse("\"Round 3: Finals\"")
        #expect(query.phrases == ["Round 3: Finals"])
        #expect(query.terms.isEmpty)
    }

    @Test func anUnclosedQuoteStaysBareWords() {
        // Mid-typing. Treating it as a literal would blank the list on the way
        // to a query that works.
        let query = SearchQuery.parse("\"open cu")
        #expect(query.phrases.isEmpty)
        #expect(query.terms == ["open", "cu"])
    }

    @Test func operatorValuesMayBeQuoted() {
        let query = SearchQuery.parse("category:\"competitive programming\"")
        #expect(query.categories == [.cp])
        #expect(query.terms.isEmpty)
    }

    @Test func fieldNamesAcceptAPrefix() {
        #expect(SearchQuery.parse("cat:ctf").categories == [.ctf])
        #expect(SearchQuery.parse("reg:vietnam").regions == [.vietnam])
    }
}

/// Nothing a person types is ever silently dropped. Every unrecognized form
/// degrades to a ranking term rather than vanishing or filtering.
@Suite struct ForgivingParse {
    @Test func anUnknownFieldKeepsItsValueAsATerm() {
        // tag: is not implemented yet (COMP-6). It must not swallow the word.
        let query = SearchQuery.parse("tag:web")
        #expect(query.categories.isEmpty)
        #expect(query.terms == ["tag:web"])
    }

    @Test func anUnknownValueKeepsItselfAsATerm() {
        let query = SearchQuery.parse("category:zzzzzz")
        #expect(query.categories.isEmpty)
        #expect(query.terms == ["zzzzzz"])
    }

    @Test func aTypedValueStillResolves() {
        #expect(SearchQuery.parse("category:hackaton").categories == [.hackathon])
    }

    @Test func aBareFieldIsSomeoneMidType() {
        // "category:" alone must not filter on nothing.
        let query = SearchQuery.parse("category:")
        #expect(query.isEmpty)
    }

    @Test func aPastedURLIsNotAnOperator() {
        // The reason field names are matched strictly while values are fuzzy.
        let query = SearchQuery.parse("https://ctftime.org/event/1")
        #expect(query.categories.isEmpty)
        #expect(query.sources.isEmpty)
        #expect(query.terms.count == 1)
    }
}

@Suite struct RoundTrip {
    @Test func serializedTextReparsesIdentically() {
        let source = "category:ctf category:ai region:vietnam source:ybox \"open cup\" hack"
        let once = SearchQuery.parse(source)
        let twice = SearchQuery.parse(once.serialized())
        #expect(once == twice)
    }

    @Test func serializationIsStable() {
        // Set iteration order must never reach the search field.
        let query = SearchQuery.parse("category:ai category:ctf")
        #expect(query.serialized() == "category:ctf category:ai")
    }
}

/// The invariant the whole feature rests on.
@Suite struct TermsNeverExclude {
    private var index: [Competition] { [openAtlas, openAI, spectral] }

    @Test func aWordMatchingNothingStillAdmitsEveryRow() {
        let query = SearchQuery.parse("zzzzzz")
        #expect(index.allSatisfy { query.admits($0) })
    }

    @Test func aPartiallyMatchedQueryAdmitsEveryRow() {
        // "open cup" - the reported case. Under the old ANDed rule this
        // returned nothing at all.
        let query = SearchQuery.parse("open cup")
        #expect(index.allSatisfy { query.admits($0) })
    }

    @Test func operatorsDoExclude() {
        // Deliberate acts are allowed to empty the list; typing is not.
        let query = SearchQuery.parse("category:design")
        #expect(!index.contains { query.admits($0) })
    }

    @Test func quotedPhrasesDoExclude() {
        #expect(!index.contains { SearchQuery.parse("\"open cup\"").admits($0) })
        #expect(index.contains { SearchQuery.parse("\"open atlas\"").admits($0) })
    }
}

@Suite struct CategoryContainment {
    /// The category filter is containment over the tag set, not equality on
    /// the leading tag: a poetry-music-photography contest belongs under
    /// writing AND media, and either sidebar entry must surface it.
    @Test func aRowIsAdmittedByEveryTagItCarries() {
        let dto = CompetitionDTO(
            source: "ybox", title: "Cuộc Thi Sáng Tác Thơ, Âm Nhạc, Nhiếp Ảnh",
            url: "https://ybox.vn/cuoc-thi/tho-nhac-anh")
        let row = Competition(dto: dto, tags: [.writing, .media], region: .vietnam)

        #expect(SearchQuery.parse("category:writing").admits(row))
        #expect(SearchQuery.parse("category:media").admits(row))
        #expect(!SearchQuery.parse("category:ctf").admits(row))
    }

    /// An unplaced row still answers to the Other sidebar entry: its empty
    /// tag set holds nothing, and the projection falls back to `.other`.
    @Test func anUnplacedRowAnswersToOther() {
        let row = comp("Mystery Gala", category: .other)
        #expect(SearchQuery.parse("category:other").admits(row))
        #expect(!SearchQuery.parse("category:media").admits(row))
    }

    /// Rows migrated from before the tags column filter by their stored
    /// category until the backfill reaches them - never by nothing.
    @Test func aPreBackfillRowFiltersByItsStoredCategory() {
        let row = comp("Declared AI Challenge", category: .ai)
        row.categoryTagsRaw = ""
        #expect(SearchQuery.parse("category:ai").admits(row))
        #expect(!SearchQuery.parse("category:media").admits(row))
    }
}

@Suite struct Ranking {
    /// The reported query. Every row that carries either word scores, which is
    /// the whole complaint: this returned nothing at all.
    @Test func openCupFindsAllThreeRealAnswers() {
        let query = SearchQuery.parse("open cup")
        #expect(query.relevance(of: openAtlas) > 0)
        #expect(query.relevance(of: openAI) > 0)
        #expect(query.relevance(of: spectral) > 0)
    }

    @Test func theWholeWordOutranksTheFragment() {
        // "Open Atlas" over "OpenAI Build Week", which substring containment
        // could not distinguish.
        let query = SearchQuery.parse("open cup")
        #expect(query.relevance(of: openAtlas) > query.relevance(of: openAI))
    }

    @Test func matchingEitherWordScoresTheSame() {
        // Open Atlas answers "open", Spectral::Cup answers "cup". Neither is a
        // better answer to "open cup" than the other, so relevance ties and the
        // list decides between them - by the chosen sort, and by putting ended
        // competitions last. Deliberately NOT a score penalty: no amount of
        // text relevance should lift a finished contest over a live one.
        let query = SearchQuery.parse("open cup")
        #expect(query.relevance(of: openAtlas) == query.relevance(of: spectral))
    }

    @Test func aTypoScoresTheSameAsTheCorrectSpelling() {
        let clean = SearchQuery.parse("open cup")
        let typo = SearchQuery.parse("opne cup")
        // One edit costs a rung, but the row still wins its comparison.
        #expect(typo.relevance(of: openAtlas) > 0)
        #expect(typo.relevance(of: openAtlas) > typo.relevance(of: openAI))
        #expect(clean.relevance(of: spectral) == typo.relevance(of: spectral))
    }

    @Test func adjacentTermsEarnThePhraseBonus() {
        let query = SearchQuery.parse("open atlas")
        let adjacent = query.relevance(of: openAtlas)
        let scattered = query.relevance(of: comp("Atlas Grand Open"))
        #expect(adjacent > scattered)
    }

    @Test func titleOutranksOrganizer() {
        let query = SearchQuery.parse("vnoi")
        #expect(query.relevance(of: comp("VNOI Cup"))
                > query.relevance(of: comp("Round 5", organizer: "VNOI")))
    }

    @Test func moreMatchedTermsRanksHigher() {
        let query = SearchQuery.parse("open cup")
        #expect(query.relevance(of: comp("Open Cup")) > query.relevance(of: comp("World Cup")))
    }

    @Test func noTermsMeansNoOpinion() {
        // Operators alone leave the chosen sort in charge.
        #expect(SearchQuery.parse("category:ctf").relevance(of: openAtlas) == 0)
    }
}

/// What decides whether finished competitions are visible.
@Suite struct FreeTextDetection {
    @Test func typingCountsAsSearching() {
        #expect(SearchQuery.parse("open").hasFreeText)
        #expect(SearchQuery.parse("\"open cup\"").hasFreeText)
    }

    @Test func browsingACategoryDoesNot() {
        // A sidebar click produces exactly this, and browsing must stay free of
        // rows that already ended.
        #expect(!SearchQuery.parse("category:ctf").hasFreeText)
        #expect(!SearchQuery.parse("").hasFreeText)
    }
}
