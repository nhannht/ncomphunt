import Foundation

/// Fuzzy text matching for search terms.
///
/// Replaces substring containment, which failed three ways at once: it could
/// not forgive a typo, it could not match Vietnamese typed without diacritics,
/// and it rated `open` inside `OpenAI` exactly as highly as the word `Open`.
///
/// Every comparison happens between FOLDED forms, and matching is per WORD of
/// the target rather than against the whole string. Per-word is what makes the
/// ladder below meaningful: "starts with" against a word is a real signal,
/// while "starts with" against a whole title only ever describes the first one.
public enum FuzzyMatch {
    // MARK: Scores

    /// The term is the word.
    public static let exact = 10
    /// The word begins with the term. `hack` against `Hackathon`.
    public static let prefix = 7
    /// One edit away. `hackaton` against `Hackathon`.
    public static let nearMiss = 5
    /// Two edits away, only allowed for longer terms.
    public static let distantMiss = 4
    /// The term sits contiguously inside the word but not at its start.
    public static let infix = 4
    /// The term's letters appear in order with gaps. `hckthn`.
    public static let subsequence = 2

    /// Below this length a term is matched exactly or by prefix only. At one or
    /// two characters an edit-distance or subsequence match hits nearly every
    /// row, which is noise rather than fuzziness.
    static let minimumLengthForLooseMatching = 3

    // MARK: Folding

    /// The single normalization both sides of every comparison pass through.
    ///
    /// The diacritic option is the highest-value part of this whole file: 69 of
    /// the 203 competitions in a typical store come from ybox and carry
    /// Vietnamese titles, and nobody types `Thiết Kế` into a search field with
    /// the tone marks. Without folding, a third of the index is unreachable to
    /// the people it was collected for.
    public static func fold(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: .current)
    }

    /// Splits on anything that is not a letter or a digit, so `Spectral::Cup`
    /// yields `spectral` and `cup` rather than one unmatchable token.
    public static func words(of text: String) -> [String] {
        fold(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    // MARK: Scoring

    /// Best score for `term` against any single word of `text`. Zero means no
    /// match. Both arguments are folded here, so callers pass raw text.
    public static func score(term: String, in text: String) -> Int {
        let folded = fold(term)
        guard !folded.isEmpty else { return 0 }
        var best = 0
        for word in words(of: text) {
            best = max(best, score(foldedTerm: folded, foldedWord: word))
            // Nothing beats an exact word match, so stop looking.
            if best == exact { break }
        }
        return best
    }

    /// Best score for `term` against a short LABEL, where the label as a whole
    /// is as meaningful as any word in it.
    ///
    /// Separate from `score(term:in:)` because the targets differ in kind. A
    /// competition title is a sentence, and a term matching one word of it is
    /// the signal. A label like "Competitive Programming" is a single name that
    /// happens to contain a space, so `category:"competitive programming"` has
    /// to be able to match the whole of it at once.
    public static func labelScore(term: String, label: String) -> Int {
        max(score(term: term, in: label),
            score(foldedTerm: fold(term), foldedWord: fold(label)))
    }

    /// The ladder, against one already-folded word.
    ///
    /// Every rung is computed and the best taken, rather than returning at the
    /// first hit. Ordering the checks would mean the ladder's ranking and the
    /// code's control flow have to agree, and they silently drift apart.
    static func score(foldedTerm term: String, foldedWord word: String) -> Int {
        if term == word { return exact }
        if word.hasPrefix(term) { return prefix }
        guard term.count >= minimumLengthForLooseMatching else { return 0 }

        var best = 0
        if word.contains(term) { best = infix }

        let limit = editLimit(for: term)
        if limit > 0, let distance = boundedDistance(term, word, limit: limit) {
            best = max(best, distance == 1 ? nearMiss : distantMiss)
        }

        if best == 0, isSubsequence(term, of: word) { best = subsequence }
        return best
    }

    /// How many edits a term of this length may be wrong by.
    ///
    /// Scaled with length because one edit in a four-character term is a
    /// quarter of it, while two edits in a twelve-character term is still
    /// recognisably the same word.
    static func editLimit(for term: String) -> Int {
        switch term.count {
        case ..<4: 0
        case ..<7: 1
        default: 2
        }
    }

    // MARK: Distance

    /// Optimal string alignment distance, bounded. Returns nil once the true
    /// distance is known to exceed `limit`, so callers never pay for an answer
    /// they would discard.
    ///
    /// Counts an adjacent transposition as one edit rather than two, because
    /// `opne` and `teh` are the typos people actually make and plain
    /// Levenshtein charges double for them.
    static func boundedDistance(_ a: String, _ b: String, limit: Int) -> Int? {
        let x = Array(a), y = Array(b)
        // Cheapest possible rejection: lengths alone can exceed the limit, and
        // this runs before any allocation.
        if abs(x.count - y.count) > limit { return nil }
        if x.isEmpty { return y.count <= limit ? y.count : nil }
        if y.isEmpty { return x.count <= limit ? x.count : nil }

        var previous2 = [Int](repeating: 0, count: y.count + 1)
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)

        for i in 1...x.count {
            current[0] = i
            var rowBest = current[0]
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                var value = min(
                    current[j - 1] + 1,      // insertion
                    previous[j] + 1,         // deletion
                    previous[j - 1] + cost)  // substitution
                if i > 1, j > 1, x[i - 1] == y[j - 2], x[i - 2] == y[j - 1] {
                    value = min(value, previous2[j - 2] + 1)  // transposition
                }
                current[j] = value
                rowBest = min(rowBest, value)
            }
            // Every remaining path runs through this row, so once its best
            // entry exceeds the limit the final answer must too.
            if rowBest > limit { return nil }
            previous2 = previous
            previous = current
        }

        let distance = previous[y.count]
        return distance <= limit ? distance : nil
    }

    /// Whether `term`'s characters appear in `word` in order, gaps allowed.
    static func isSubsequence(_ term: String, of word: String) -> Bool {
        var remaining = Substring(term)
        for character in word where character == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }

    // MARK: Phrases

    /// Literal containment, folded on both sides. This is what a quoted phrase
    /// uses: quotes are how a person turns the fuzziness off, so this rung has
    /// no ladder and no tolerance.
    public static func containsLiterally(_ phrase: String, in text: String) -> Bool {
        let needle = fold(phrase)
        guard !needle.isEmpty else { return true }
        return fold(text).contains(needle)
    }

    /// Whether every term appears in order and adjacent in `text`, which earns
    /// a query its phrase bonus without the person having to quote anything.
    public static func containsAdjacently(_ terms: [String], in text: String) -> Bool {
        guard terms.count > 1 else { return false }
        let haystack = words(of: text)
        let needles = terms.map(fold)
        guard needles.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needles.count) {
            let window = haystack[start..<(start + needles.count)]
            if zip(window, needles).allSatisfy({ $0 == $1 }) { return true }
        }
        return false
    }
}
