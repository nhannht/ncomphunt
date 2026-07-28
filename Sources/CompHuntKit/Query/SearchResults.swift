import Foundation

/// What the list should show, and whether the query actually found it.
public struct SearchResults {
    public let items: [Competition]
    /// True when nothing answered the text and the list fell back to showing
    /// everything current. The caller MUST say so: someone who typed a word and
    /// got the whole index back with no explanation is more confused than they
    /// were by the blank screen this replaces.
    public let isFallback: Bool
}

public extension SearchQuery {
    /// The rows to show, in the order to show them.
    ///
    /// Lives here rather than in the view for two reasons. The ordering is the
    /// part most easily got wrong and least visible when it is - a list can
    /// look plausible while quietly burying the row that answered the question.
    /// And the empty-result rule is a decision about the SET, not about any one
    /// row, so it cannot be expressed as a per-row predicate at all.
    ///
    /// The rule:
    ///
    /// - A row MATCHES when the constraints admit it and it answers the text -
    ///   either by scoring, or by containing a quoted phrase, which is a
    ///   literal match and needs no score to prove it.
    /// - If anything matches, show the matches. Ended competitions included:
    ///   they come through the same door as live ones and are merely sorted
    ///   last, so a search never hides the one real answer for having closed.
    /// - If nothing matches, show everything current that the constraints
    ///   admit, and set `isFallback`.
    ///
    /// So typing can still never produce a blank screen, but it also does not
    /// return the whole index ranked. Words behave the way words behave in a
    /// search box: they find things.
    ///
    /// - Parameter tieBreak: the person's chosen sort, consulted whenever
    ///   relevance has no opinion.
    func results(
        from competitions: [Competition],
        now: Date = .now,
        tieBreak: (Competition, Competition) -> Bool
    ) -> SearchResults {
        let admitted = competitions.filter { admits($0, now: now) }
        // A quoted phrase is proof of a match on its own. Requiring a score
        // too would blank the list whenever the only row carrying the phrase
        // had ended - and the diagnosis would then blame the phrase that was
        // right.
        let matched = admitted.filter { relevance(of: $0) > 0 || !phrases.isEmpty }
        let fellBack = matched.isEmpty
        let rows = fellBack ? admitted.filter { $0.isCurrent(asOf: now) } : matched

        let ranked = !terms.isEmpty
        let sorted = rows
            .map { (item: $0, score: relevance(of: $0), ended: !$0.isCurrent(asOf: now)) }
            .sorted { a, b in
                // Finished competitions always sit below every live one. A
                // separate key rather than a score penalty, so no amount of
                // text relevance can lift a contest nobody can still enter
                // above one they can.
                if a.ended != b.ended { return b.ended }
                // Relevance outranks the chosen sort ONLY while text is
                // present: someone who typed something is asking which of
                // these is what they meant, not which is soonest.
                if ranked, a.score != b.score { return a.score > b.score }
                return tieBreak(a.item, b.item)
            }
            .map(\.item)

        // Browsing is not a failed search, so it is never reported as one.
        return SearchResults(items: sorted, isFallback: fellBack && hasFreeText)
    }
}
