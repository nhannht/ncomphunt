import Foundation

/// One row of the search field's autocomplete.
///
/// Carries the FULL replacement text rather than the fragment to append.
/// SwiftUI's `.searchCompletion` replaces the whole field, and computing the
/// replacement here keeps the view from having to re-derive where the trailing
/// token started - the one place an off-by-one would silently eat a person's
/// text.
public struct SearchSuggestion: Identifiable, Equatable, Sendable {
    /// What the person is choosing, in their words.
    public let label: String
    /// Secondary text: what the operator does, or which field a value belongs to.
    public let detail: String
    /// The entire new contents of the search field.
    public let completion: String

    public var id: String { completion }

    public init(label: String, detail: String, completion: String) {
        self.label = label
        self.detail = detail
        self.completion = completion
    }
}

public extension SearchQuery {
    /// What to offer given what has been typed so far.
    ///
    /// Only the TRAILING token is considered. Everything before it is already
    /// settled and is carried through untouched, so choosing a suggestion never
    /// disturbs a filter that was set three tokens ago.
    static func suggestions(for text: String) -> [SearchSuggestion] {
        // Deliberately naive splitting: only the last run of non-space matters,
        // and a suggestion is never offered mid-quote.
        let trailing = String(text.split(separator: " ", omittingEmptySubsequences: false).last ?? "")
        guard !trailing.isEmpty, !trailing.contains("\"") else { return [] }
        let head = String(text.dropLast(trailing.count))

        guard let colon = trailing.firstIndex(of: ":"),
              let field = Field.named(String(trailing[..<colon]))
        else {
            // A bare word. Offer the operators it could be the start of, and
            // nothing else - a person typing "open" is searching, not filtering,
            // so a dropdown of every category would be in the way.
            let folded = FuzzyMatch.fold(trailing)
            return Field.allCases
                .filter { $0.rawValue.hasPrefix(folded) }
                .map {
                    SearchSuggestion(label: $0.token, detail: $0.hint,
                                     completion: head + $0.token)
                }
        }

        let partial = String(trailing[trailing.index(after: colon)...])
        return field.values
            .filter { partial.isEmpty || Self.offers($0, for: partial) }
            .map {
                SearchSuggestion(
                    label: $0.label, detail: field.rawValue,
                    // Trailing space so the next token starts cleanly.
                    completion: head + field.token + $0.value + " ")
            }
    }

    /// Whether a candidate value is worth showing for what has been typed.
    /// Fuzzy, matching how the value would resolve if the person just kept
    /// typing - the dropdown must never omit something the parser would accept.
    private static func offers(_ candidate: (value: String, label: String), for partial: String) -> Bool {
        FuzzyMatch.labelScore(term: partial, label: candidate.value) > 0
            || FuzzyMatch.labelScore(term: partial, label: candidate.label) > 0
    }
}
