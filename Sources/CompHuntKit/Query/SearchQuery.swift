import Foundation

/// What the person typed into the search field, parsed.
///
/// The query does not select a subset. It ORDERS the list, and only explicit
/// operators narrow it. That distinction is the whole design: typing words can
/// never produce a blank screen, because words are a preference and preferences
/// do not exclude. Anything that DOES exclude has to be deliberate - an
/// operator, or a quoted phrase - and then a blank result is an honest answer
/// to a precise question rather than a dead end.
///
/// ```
/// open cup          fuzzy, ranks only, can never empty the list
/// "Open Cup"        literal and exact, filters
/// category:ctf      filters
/// region:vietnam    filters
/// source:ctftime    filters
/// ```
public struct SearchQuery: Equatable, Sendable {
    // MARK: Constraints - every one is a closed set or a literal the person quoted

    public var categories: Set<CompetitionCategory>
    public var regions: Set<Region>
    public var sources: Set<SourceID>
    /// Pipeline states to keep. Non-empty means "only things I have marked",
    /// because an unmarked competition has no status to be in the set.
    /// `status:any` fills it with every case, which is how "show me everything
    /// I marked" is expressed without a second boolean to disagree with.
    public var statuses: Set<CompetitionStatus>
    /// How soon the next date has to fall, in days.
    ///
    /// Stored as a RELATIVE window rather than the absolute pair it replaces.
    /// Absolute dates cannot survive a round trip through the search field, and
    /// a persisted one goes quietly stale overnight - "closing this week" would
    /// still mean the week it was typed in.
    public var withinDays: Int?
    /// Quoted runs. Quotes are how a person turns the fuzziness OFF, which is
    /// why this is the one text form allowed to filter.
    public var phrases: [String]

    // MARK: Preference

    /// Bare words. Fuzzy, never ANDed, never a gate.
    public var terms: [String]

    public init(
        categories: Set<CompetitionCategory> = [],
        regions: Set<Region> = [],
        sources: Set<SourceID> = [],
        statuses: Set<CompetitionStatus> = [],
        withinDays: Int? = nil,
        phrases: [String] = [],
        terms: [String] = []
    ) {
        self.categories = categories
        self.regions = regions
        self.sources = sources
        self.statuses = statuses
        self.withinDays = withinDays
        self.phrases = phrases
        self.terms = terms
    }

    public var isEmpty: Bool {
        categories.isEmpty && regions.isEmpty && sources.isEmpty
            && statuses.isEmpty
            && withinDays == nil && phrases.isEmpty && terms.isEmpty
    }

    /// Whether this query is asking only for marked competitions. The Marked
    /// chip reads its highlight out of this, the same way the category chips
    /// read theirs out of `categories`.
    public var isMarkedOnly: Bool { !statuses.isEmpty }

    /// Whether the person typed anything to search FOR, as opposed to a lens to
    /// look through.
    ///
    /// This is what governs whether finished competitions appear. It cannot be
    /// `isEmpty`, because clicking a sidebar category also produces a query -
    /// and browsing a category is not searching, so it must stay free of rows
    /// that already ended.
    public var hasFreeText: Bool { !terms.isEmpty || !phrases.isEmpty }

    // MARK: Filtering

    /// Whether this competition survives the constraints. Bare terms are
    /// deliberately not consulted: that omission is the invariant making an
    /// empty list unreachable by typing.
    public func admits(_ competition: Competition, now: Date = .now) -> Bool {
        // Containment over the tag set, not equality on the single category: a
        // poetry-music-photography contest belongs under writing AND media,
        // and clicking either sidebar entry must surface it.
        if !categories.isEmpty, !categories.contains(where: competition.belongs(to:)) { return false }
        if !regions.isEmpty, !regions.contains(competition.region) { return false }
        if !sources.isEmpty {
            guard let id = SourceID(rawValue: competition.source),
                  sources.contains(id) else { return false }
        }
        if !statuses.isEmpty {
            // An unmarked competition has no status, so it fails every status
            // filter - including `status:any`, which is exactly right.
            guard let status = competition.status,
                  statuses.contains(status) else { return false }
        }
        if let withinDays {
            // A row with no date cannot honestly satisfy "closing this week".
            guard let date = competition.nextRelevantDate else { return false }
            let limit = now.addingTimeInterval(Double(withinDays) * 86_400)
            if date < now || date > limit { return false }
        }
        for phrase in phrases {
            let found = FuzzyMatch.containsLiterally(phrase, in: competition.title)
                || FuzzyMatch.containsLiterally(phrase, in: competition.organizer)
            if !found { return false }
        }
        return true
    }

    // MARK: Ranking

    /// All terms adjacent and in order in the title. Earns a query the phrase
    /// ordering without the person having to quote anything.
    static let phraseBonus = 6

    /// How well this competition answers the free text. Never excludes; zero
    /// simply means nothing was asked for, or nothing matched.
    public func relevance(of competition: Competition) -> Int {
        guard !terms.isEmpty else { return 0 }
        var total = 0
        for term in terms {
            let title = FuzzyMatch.score(term: term, in: competition.title)
            // A match on the organizer counts half. Sponsoring a contest is
            // weaker evidence than being named one.
            let organizer = FuzzyMatch.score(term: term, in: competition.organizer) / 2
            total += max(title, organizer)
        }
        if FuzzyMatch.containsAdjacently(terms, in: competition.title) {
            total += Self.phraseBonus
        }
        return total
    }

    // MARK: Fields

    /// The operators the language understands. `tag:` joins this list once
    /// competitions persist their tags (COMP-6).
    public enum Field: String, CaseIterable, Sendable {
        case category, region, source, status, deadline

        /// Shown in the autocomplete.
        public var token: String { "\(rawValue):" }

        /// One line describing what the operator does.
        public var hint: String {
            switch self {
            case .category: "Competition kind"
            case .region: "Where it runs"
            case .source: "Which feed found it"
            case .status: "How you marked it"
            case .deadline: "Closing within"
            }
        }

        /// Everything this field accepts, in the order the autocomplete offers
        /// it. Drawn from the same enums the rest of the app renders, so a
        /// label can never drift from what the list shows.
        public var values: [(value: String, label: String)] {
            switch self {
            case .category:
                CompetitionCategory.allCases.map { ($0.rawValue, $0.displayName) }
            case .region:
                Region.allCases.map { ($0.rawValue, $0.displayName) }
            case .source:
                SourceID.allCases.map { ($0.rawValue, $0.displayName) }
            case .status:
                // `any` leads: "everything I marked" is the common ask, and the
                // individual states are the refinement.
                [(SearchQuery.anyStatusToken, "Anything you marked")]
                    + CompetitionStatus.allCases.map { ($0.rawValue, $0.displayName) }
            case .deadline:
                DeadlineSpan.all.map {
                    ($0.searchAliases[0], "Within \($0.days) day\($0.days == 1 ? "" : "s")")
                }
            }
        }

        /// Exact name, or a prefix of at least three characters so `cat:` works.
        ///
        /// Field names are matched strictly rather than fuzzily, unlike their
        /// values. A fuzzy field name turns every colon a person types - in a
        /// pasted URL, in `Round 3: Finals` - into a filter they did not ask
        /// for, and silently dropping their text is the exact failure this
        /// whole feature exists to remove.
        static func named(_ text: String) -> Field? {
            let folded = FuzzyMatch.fold(text)
            guard folded.count >= 3 else { return nil }
            return allCases.first { $0.rawValue == folded }
                ?? allCases.first { $0.rawValue.hasPrefix(folded) }
        }
    }

    // MARK: Parsing

    public static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery()
        for token in tokenize(text) {
            switch token {
            case .quoted(let phrase):
                let trimmed = phrase.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { query.phrases.append(trimmed) }
            case .bare(let word):
                query.absorb(word)
            }
        }
        return query
    }

    /// One bare token, which may or may not be an operator.
    private mutating func absorb(_ token: String) {
        guard let colon = token.firstIndex(of: ":"),
              let field = Field.named(String(token[..<colon]))
        else {
            terms.append(token)
            return
        }
        let value = String(token[token.index(after: colon)...])
        // `category:` alone is someone mid-type, not a filter on nothing.
        guard !value.isEmpty else { return }
        guard apply(field, value) else {
            // An unresolvable value is still something the person typed, so it
            // becomes a ranking term rather than vanishing.
            terms.append(value)
            return
        }
    }

    /// Resolves a value against the field's closed set. Values ARE matched
    /// fuzzily - `category:hackaton` should still mean Hackathon - which is
    /// safe here in a way fuzzy field names are not, because the candidate set
    /// is small, known, and offered in the autocomplete.
    private mutating func apply(_ field: Field, _ value: String) -> Bool {
        switch field {
        case .category:
            guard let match = Self.resolve(value, among: CompetitionCategory.allCases,
                                           aliases: \.searchAliases) else { return false }
            categories.insert(match)
        case .region:
            guard let match = Self.resolve(value, among: Region.allCases,
                                           aliases: \.searchAliases) else { return false }
            regions.insert(match)
        case .source:
            guard let match = Self.resolve(value, among: SourceID.allCases,
                                           aliases: \.searchAliases) else { return false }
            sources.insert(match)
        case .status:
            // `any` is not a state, it is all of them - which keeps "marked at
            // all" and "marked as applied" on one axis instead of two.
            if FuzzyMatch.fold(value) == Self.anyStatusToken
                || FuzzyMatch.fold(value) == "marked" {
                statuses.formUnion(CompetitionStatus.allCases)
                return true
            }
            guard let match = Self.resolve(value, among: CompetitionStatus.allCases,
                                           aliases: \.searchAliases) else { return false }
            statuses.insert(match)
        case .deadline:
            guard let days = Self.days(from: value) else { return false }
            // Narrowest wins, so `deadline:week deadline:month` means week.
            withinDays = min(withinDays ?? days, days)
        }
        return true
    }

    /// The value that means "in any pipeline state at all".
    public static let anyStatusToken = "any"

    /// A window a person can name, as days.
    struct DeadlineSpan {
        let days: Int
        let searchAliases: [String]

        static let all: [DeadlineSpan] = [
            DeadlineSpan(days: 1, searchAliases: ["today", "now"]),
            DeadlineSpan(days: 2, searchAliases: ["tomorrow"]),
            DeadlineSpan(days: 7, searchAliases: ["week", "soon"]),
            DeadlineSpan(days: 14, searchAliases: ["fortnight"]),
            DeadlineSpan(days: 30, searchAliases: ["month"]),
            DeadlineSpan(days: 90, searchAliases: ["quarter"]),
            DeadlineSpan(days: 365, searchAliases: ["year"]),
        ]
    }

    /// A deadline window: a plain number of days, `30d`, or a named span.
    static func days(from value: String) -> Int? {
        let folded = FuzzyMatch.fold(value)
        let numeric = folded.hasSuffix("d") ? String(folded.dropLast()) : folded
        if let days = Int(numeric), days > 0 { return days }
        return Self.resolve(folded, among: DeadlineSpan.all,
                            aliases: \.searchAliases)?.days
    }

    static func resolve<T>(
        _ value: String, among candidates: [T], aliases: KeyPath<T, [String]>
    ) -> T? {
        var best: (candidate: T, score: Int)?
        for candidate in candidates {
            let score = candidate[keyPath: aliases]
                .map { FuzzyMatch.labelScore(term: value, label: $0) }
                .max() ?? 0
            guard score > 0 else { continue }
            if best == nil || score > best!.score {
                best = (candidate, score)
            }
        }
        return best?.candidate
    }

    // MARK: Tokenizing

    enum Token: Equatable {
        case bare(String)
        case quoted(String)
    }

    /// Splits on whitespace, except inside quotes.
    ///
    /// An UNCLOSED quote yields bare words rather than a phrase. Someone typing
    /// `"open cu` is mid-thought, and treating that as a literal filter would
    /// blank the list on the way to a query that works - the list stays useful
    /// until the closing quote says otherwise.
    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var quoting = false
        /// Whether the open quote followed an operator's colon, as in
        /// `category:"competitive programming"`. Tracked from the OPENING quote
        /// rather than inferred at the closing one: a quoted phrase can itself
        /// contain a colon, and `"Round 3: Finals"` must stay a phrase.
        var quotingOperatorValue = false

        func flushBare() {
            guard !current.isEmpty else { return }
            tokens.append(.bare(current))
            current = ""
        }

        for character in text {
            if character == "\"" {
                if quoting {
                    quoting = false
                    // An operator's quoted value rejoins its token; a standalone
                    // quoted run becomes a phrase.
                    if !quotingOperatorValue {
                        tokens.append(.quoted(current))
                        current = ""
                    }
                } else {
                    quotingOperatorValue = current.hasSuffix(":")
                    if !quotingOperatorValue { flushBare() }
                    quoting = true
                }
            } else if character.isWhitespace && !quoting {
                flushBare()
            } else {
                current.append(character)
            }
        }

        if quoting && !quotingOperatorValue {
            for word in current.split(whereSeparator: \.isWhitespace) {
                tokens.append(.bare(String(word)))
            }
        } else {
            flushBare()
        }
        return tokens
    }

    // MARK: Serializing

    /// Round-trips through `parse`. Used whenever something other than typing
    /// produces a query - a sidebar click, or the on-device model - so those
    /// paths write the same syntax a person writes by hand and stay editable.
    public func serialized() -> String {
        var parts: [String] = []
        // Fixed taxonomy order rather than Set order, so the same query always
        // serializes to the same string.
        parts += CompetitionCategory.allCases.filter(categories.contains)
            .map { "category:\($0.rawValue)" }
        parts += Region.allCases.filter(regions.contains)
            .map { "region:\($0.rawValue)" }
        parts += SourceID.allCases.filter(sources.contains)
            .map { "source:\($0.rawValue)" }
        // Every state collapses back to `status:any`, so the Marked chip's
        // round trip stays one short token instead of five.
        if statuses.count == CompetitionStatus.allCases.count {
            parts.append("status:\(Self.anyStatusToken)")
        } else {
            parts += CompetitionStatus.allCases.filter(statuses.contains)
                .map { "status:\($0.rawValue)" }
        }
        if let withinDays { parts.append("deadline:\(withinDays)d") }
        parts += phrases.map { "\"\($0)\"" }
        parts += terms
        return parts.joined(separator: " ")
    }
}

// MARK: - What each closed set answers to

extension CompetitionCategory {
    /// Spellings a person might type for this category.
    var searchAliases: [String] {
        switch self {
        case .cp: [rawValue, displayName, "competitive", "programming", "algorithm"]
        case .ctf: [rawValue, "capture the flag", "security", "hacking", "pwn"]
        case .ai: [rawValue, "machine learning", "ml", "data science", "kaggle"]
        case .hackathon: [rawValue, "hack"]
        case .design: [rawValue, "art", "poster", "creative"]
        case .writing: [rawValue, "essay", "poem", "story", "slogan", "review"]
        case .media: [rawValue, "photo", "photography", "film", "video", "music"]
        case .business: [rawValue, "startup", "pitch", "case", "entrepreneur"]
        case .academic: [rawValue, "quiz", "debate", "speech", "maths", "scholarship"]
        case .other: [rawValue, "misc"]
        }
    }
}

extension Region {
    var searchAliases: [String] {
        switch self {
        case .vietnam: [rawValue, "viet nam", "vietnamese", "vn", "local"]
        case .global: [rawValue, "international", "worldwide", "world", "abroad"]
        }
    }
}

extension SourceID {
    var searchAliases: [String] { [rawValue, displayName] }
}
