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
    deadline: Date? = nil,
    end: Date? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: "test", title: title, organizer: organizer,
        url: "https://example.com/\(title)",
        endDate: end, registrationDeadline: deadline)
    return Competition(dto: dto, category: category, region: region)
}

/// The situation that prompted this: a generated query carried a category, and
/// that category held one current competition while the others held dozens.
/// Nothing on screen distinguished the expensive constraint from the cheap ones.
@Suite struct NarrowestConstraint {
    /// Shaped like the real store, including the two rows that actually carry
    /// the words: plenty of CTF and AI, exactly one current CP row, and
    /// "open" appearing only outside the CP category.
    private var index: [Competition] {
        var rows = (1...12).map { comp("CTF Event \($0)", category: .ctf) }
        rows += (1...8).map { comp("AI Contest \($0)", category: .ai) }
        rows.append(comp("Codeforces Round 1109", category: .cp))
        rows.append(comp("Open Atlas - AI for Social Good Hackathon 2026", category: .hackathon))
        rows.append(comp("OpenAI Build Week", category: .ai))
        return rows
    }

    @Test func namesTheCategoryHoldingAlmostNothing() {
        // The reported case exactly: "open cup" resolved to Competitive
        // Programming plus two terms, and showed nothing. The category is what
        // emptied it - the words match two rows in other categories.
        let query = CompetitionQuery(
            categories: [.cp], terms: CompetitionQuery.tokenize("open cup"))
        #expect(query.matchCount(in: index, now: now) == 0)

        let diagnosis = query.narrowestConstraint(in: index, now: now)
        #expect(diagnosis?.axis == .category(.cp))
        #expect(diagnosis?.countWithout == 2)
    }

    @Test func staysSilentWhenNoSingleRemovalHelps() {
        // Constraints can be jointly unsatisfiable. Naming one axis then would
        // promise results that removing it does not produce, so the honest
        // answer is nothing and the caller falls back to clearing everything.
        // `.design` holds nothing here and no title carries the word, so
        // dropping either one alone still shows zero.
        let query = CompetitionQuery(
            categories: [.design], terms: CompetitionQuery.tokenize("unmatchable"))
        #expect(query.narrowestConstraint(in: index, now: now) == nil)
    }

    @Test func picksTheAxisThatRevealsTheMost() {
        // Two constraints, one far more expensive than the other.
        let query = CompetitionQuery(categories: [.cp], region: .vietnam)
        let diagnosis = query.narrowestConstraint(in: index, now: now)
        // Every row is global, so region is the one hiding everything.
        #expect(diagnosis?.axis == .region(.vietnam))
        #expect(diagnosis?.countWithout == 1)
    }

    @Test func aTermCanBeTheExpensiveOne() {
        let query = CompetitionQuery(
            categories: [.ctf], terms: CompetitionQuery.tokenize("unmatchable"))
        let diagnosis = query.narrowestConstraint(in: index, now: now)
        #expect(diagnosis?.axis == .term("unmatchable"))
        #expect(diagnosis?.countWithout == 12)
    }

    @Test func aDateWindowCanBeTheExpensiveOne() {
        let rows = [comp("Soon", category: .ctf, deadline: now.addingTimeInterval(60 * day))]
        let query = CompetitionQuery(
            categories: [.ctf], deadlineBefore: now.addingTimeInterval(day))
        let diagnosis = query.narrowestConstraint(in: rows, now: now)
        #expect(diagnosis?.axis == .deadline)
        #expect(diagnosis?.countWithout == 1)
    }

    @Test func silentWhenNothingWouldHelp() {
        // An empty store is not the query's fault, so there is nothing to
        // suggest and the caller should say something else entirely.
        let query = CompetitionQuery(categories: [.ctf])
        #expect(query.narrowestConstraint(in: [], now: now) == nil)
    }

    @Test func silentWhenTheListIsAlreadyFull() {
        // Never nag about a filter that is not costing anything.
        let query = CompetitionQuery()
        #expect(query.narrowestConstraint(in: index, now: now) == nil)
    }

    @Test func expiredRowsAreNeverOfferedAsARescue() {
        // The real cause of the blank screen: the only matching row had ended.
        // Suggesting a removal that reveals it would be a lie.
        let expired = comp("Spectral Cup 2026", category: .cp,
                           end: now.addingTimeInterval(-12 * day))
        let query = CompetitionQuery(
            categories: [.cp], terms: CompetitionQuery.tokenize("cup"))
        #expect(query.narrowestConstraint(in: [expired], now: now) == nil)
    }
}

@Suite struct AxisRemoval {
    @Test func eachAxisRemovesOnlyItself() {
        var query = CompetitionQuery(
            categories: [.ctf, .ai], region: .vietnam,
            deadlineBefore: now, terms: ["a", "b"])

        query.remove(.category(.ctf))
        #expect(query.categories == [.ai])

        query.remove(.region(.vietnam))
        #expect(query.region == nil)

        query.remove(.deadline)
        #expect(query.deadlineBefore == nil)

        query.remove(.term("a"))
        #expect(query.terms == ["b"])
    }

    @Test func activeAxesMirrorWhatTheChipsShow() {
        let query = CompetitionQuery(
            categories: [.ctf], region: .vietnam,
            deadlineBefore: now, terms: ["zalo"])
        #expect(query.activeAxes == [
            .category(.ctf), .region(.vietnam), .deadline, .term("zalo"),
        ])
    }

    @Test func anEmptyQueryHasNoAxes() {
        #expect(CompetitionQuery().activeAxes.isEmpty)
    }
}
