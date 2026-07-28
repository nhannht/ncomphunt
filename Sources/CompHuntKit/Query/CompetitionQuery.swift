import Foundation

/// One composite filter over the competition list.
///
/// Before this existed the filter state was three uncoordinated pieces held in
/// the app layer: a category enum in the sidebar, a region enum in the toolbar,
/// and a bare search string in `MainWindow`. Nothing could express "AI contests
/// in Vietnam closing this month" as a single value, and none of it was
/// testable without launching SwiftUI.
///
/// Every filtering surface now produces one of these and the list consumes only
/// this, so a natural-language query is another way to drive the filtering that
/// already works rather than a second, parallel path.
///
/// ## Constraints filter, preferences rank
///
/// The axes split into two kinds, and conflating them is what made an earlier
/// version return a blank list. Everything above `terms` is a CONSTRAINT: the
/// person said it, so a row that fails it is genuinely not wanted. `terms` is a
/// PREFERENCE: free text that orders results rather than gating them, because a
/// single word nothing happens to contain must not be able to erase a hundred
/// correctly-matched rows.
///
/// Deliberately absent: a prize floor and an effort ceiling. Both need
/// `PrizeNormalizer` and `EffortEstimator`, which do not exist yet, and a filter
/// axis nothing can evaluate is worse than an absent one - it would render a
/// chip claiming a constraint the list never applied. They arrive with the code
/// that enforces them.
public struct CompetitionQuery: Equatable, Sendable {
    // MARK: Constraints
    //
    // Every one is a CLOSED SET - an enum, an enum, two dates. That is not a
    // coincidence and it is the invariant to preserve: a generated value can
    // only ever be one of a handful of legal answers, so it can narrow the list
    // wrongly but can never reduce it to nothing. Free text, which a generator
    // invents and which therefore matches no title at all when it guesses,
    // belongs in `terms` below. Adding a gating text field would reintroduce
    // the blank-list defect this shape exists to prevent.

    /// Empty means any category.
    public var categories: Set<CompetitionCategory>
    /// nil means any region.
    public var region: Region?
    /// Bounds on `nextRelevantDate`. A dateless competition satisfies neither.
    public var deadlineAfter: Date?
    public var deadlineBefore: Date?

    // MARK: Preference

    /// Free-text terms, already tokenized. Ranks results; never gates them
    /// beyond requiring that at least one term matched somewhere.
    public var terms: [String]

    public init(
        categories: Set<CompetitionCategory> = [],
        region: Region? = nil,
        deadlineAfter: Date? = nil,
        deadlineBefore: Date? = nil,
        terms: [String] = []
    ) {
        self.categories = categories
        self.region = region
        self.deadlineAfter = deadlineAfter
        self.deadlineBefore = deadlineBefore
        self.terms = terms
    }

    /// Splits free text into terms the way the search field should.
    ///
    /// Whitespace only. "open cup" becomes two terms that can match a title
    /// carrying both words apart, which a single substring test could not.
    public static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// No axis is constrained, so every competition matches. Drives the
    /// "nothing is filtered" affordances.
    public var isEmpty: Bool {
        categories.isEmpty
            && region == nil
            && deadlineAfter == nil
            && deadlineBefore == nil
            && terms.isEmpty
    }

    /// nil when the competition is excluded. Otherwise its relevance, where a
    /// higher number is a better text match and 0 means no text was asked for.
    ///
    /// One function rather than a separate predicate and scorer, so inclusion
    /// and rank can never disagree about the same row.
    ///
    /// Currency (is this contest still open?) is deliberately NOT decided here.
    /// `isCurrent(asOf:)` remains a separate concern the caller applies, exactly
    /// as it did before this type existed.
    public func score(_ competition: Competition) -> Int? {
        if !categories.isEmpty, !categories.contains(competition.category) {
            return nil
        }
        if let region, competition.region != region {
            return nil
        }
        if deadlineAfter != nil || deadlineBefore != nil {
            // A window is active, so a competition with no date cannot satisfy
            // it. Claiming otherwise would show dateless rows under a filter
            // that explicitly asked for a date range.
            guard let date = competition.nextRelevantDate else { return nil }
            if let deadlineAfter, date < deadlineAfter { return nil }
            if let deadlineBefore, date > deadlineBefore { return nil }
        }

        let wanted = terms.filter { !$0.isEmpty }
        guard !wanted.isEmpty else { return 0 }

        // A title hit is worth more than an organizer hit: people search for
        // what a contest IS far more often than for who runs it.
        var total = 0
        for term in wanted {
            if competition.title.localizedCaseInsensitiveContains(term) {
                total += 2
            } else if competition.organizer.localizedCaseInsensitiveContains(term) {
                total += 1
            }
        }
        // Nothing matched at all, so this is not a weak result, it is a wrong
        // one. Excluding beats ranking it last.
        guard total > 0 else { return nil }

        // Adjacency bonus, so a row containing the exact phrase outranks one
        // that merely scattered the same words.
        if wanted.count > 1 {
            let phrase = wanted.joined(separator: " ")
            if competition.title.localizedCaseInsensitiveContains(phrase) {
                total += 3
            }
        }
        return total
    }

    /// Whether the competition survives the filter at all, ignoring rank.
    public func matches(_ competition: Competition) -> Bool {
        score(competition) != nil
    }
}
