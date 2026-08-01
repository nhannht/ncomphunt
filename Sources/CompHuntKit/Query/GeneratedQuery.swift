import Foundation
import FoundationModels

/// The shape the on-device model is asked to fill in.
///
/// Mirrors of `CompetitionCategory` and `Region` rather than the model types
/// themselves: annotating the data model with `@Generable` would couple every
/// consumer of those types to Foundation Models for the benefit of this one
/// file pair. Enums rather than strings because guided generation then makes an
/// invalid category unrepresentable instead of merely unlikely.
///
/// Deliberately absent: a prize floor and an effort ceiling. Nothing can
/// evaluate either yet, and offering the model an axis the list cannot apply
/// would produce a filter chip that silently does nothing.
@Generable(description: "A kind of competition")
enum QueryCategory {
    case competitiveProgramming
    case captureTheFlagSecurity
    case artificialIntelligence
    case hackathon
    case design

    var kitValue: CompetitionCategory {
        switch self {
        case .competitiveProgramming: .cp
        case .captureTheFlagSecurity: .ctf
        case .artificialIntelligence: .ai
        case .hackathon: .hackathon
        case .design: .design
        }
    }
}

/// Three cases, and `anywhere` is the point of the design.
///
/// Measured, in order. An optional two-case enum (vietnam/global) produced a
/// spurious `global` whenever the request named no place, which in a
/// Vietnam-first index hides a third of the data. Rewording the guide moved
/// that failure between phrasings without removing it. Replacing it with a
/// required `Bool` was worse still: the flag came back true for almost
/// everything, over-constraining the opposite way.
///
/// The pattern behind all three failures is the same. The schema offered no
/// way to say "they named no place" as a POSITIVE choice - only as an absence,
/// via nil or false - and guided generation fills fields rather than leaving
/// them. So the fix is to make "no constraint" an explicit, selectable answer
/// instead of the thing you get by declining to answer.
@Generable(description: "Which region the person asked for")
enum QueryRegion {
    /// They named no place. The common case.
    case anywhere
    case vietnam
    case international

    var kitValue: Region? {
        switch self {
        case .anywhere: nil
        case .vietnam: .vietnam
        case .international: .global
        }
    }
}

@Generable(description: "A filter over a list of competitions")
struct GeneratedQuery {
    @Guide(description: "The kinds of competition the person asked for. Leave empty if they named none.")
    var categories: [QueryCategory]

    @Guide(description: "Use anywhere unless the person named a place. Use vietnam if they mentioned Vietnam or a Vietnamese city such as Hanoi or Saigon. Use international only if they explicitly asked for worldwide or international competitions. Most requests are anywhere.")
    var region: QueryRegion

    /// Singular and optional on purpose. An earlier `keywords: [String]` was a
    /// bucket, and the model reliably dumped a restatement of the whole request
    /// into it: "graphic design work", "security competitions", "AI in
    /// Vietnam". Those phrases appear in no competition title, so applying them
    /// literally erased every row the other axes had correctly found. A single
    /// optional field asks one precise question with an obvious empty answer,
    /// which removes the failure by construction rather than by prompting.
    @Guide(description: "The name of ONE specific event, brand, or organizer, such as Zalo or Codeforces. Leave empty unless the person named a particular one. Never a kind of competition, a place, or a time - those belong in the other fields. For \"AI contests in Vietnam next month\" this is empty.")
    var eventName: String?

    @Guide(description: "The deadline must fall within this many days from today. Leave empty if the person gave no timeframe.")
    var withinDays: Int?
}

/// Words that name a filter axis rather than an event.
///
/// Guided generation reliably extracts the right information and then
/// occasionally files it in the wrong field: "AI competitions in Vietnam"
/// really does come back with Vietnam as a keyword and no region set. Left
/// alone that is not a cosmetic flaw, it inverts the result - "Vietnam" as a
/// keyword demands the literal word in a title or organizer, which is exactly
/// what the classifier's region detection exists to avoid, so the list comes
/// back empty.
///
/// Moving a misfiled word to its own axis is therefore the honest repair.
/// Dropping it would lose a constraint the person asked for; keeping it would
/// apply one they did not.
///
/// Matched on the whole keyword only. "Vietnam" becomes a region; "Vietnam
/// National Olympiad" stays a keyword, because it names an event.
private enum AxisVocabulary {
    static let vietnamNames: Set<String> = [
        "vietnam", "viet nam", "vietnamese", "vn",
        "hanoi", "ha noi", "saigon", "sai gon", "ho chi minh city",
    ]

    /// Words that make a region answer trustworthy.
    static func mentionsAPlace(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let placeWords = vietnamNames.union(
            ["global", "international", "worldwide", "abroad", "overseas", "anywhere in the world"])
        return placeWords.contains { lowered.contains($0) }
    }

    static let categories: [String: CompetitionCategory] = [
        "competitive programming": .cp, "cp": .cp, "programming contest": .cp,
        "ctf": .ctf, "capture the flag": .ctf, "capture-the-flag": .ctf,
        "ai": .ai, "artificial intelligence": .ai, "machine learning": .ai, "ml": .ai,
        "hackathon": .hackathon, "hackathons": .hackathon,
        "design": .design, "design contest": .design,
    ]
}

extension SearchQuery {
    /// Pure translation, no model involvement, so it is fully testable.
    ///
    /// `now` is a parameter rather than `Date()` read inside, so "closing this
    /// month" resolves to a fixed window under test.
    init(_ generated: GeneratedQuery, from text: String, now: Date) {
        var categories = Set(generated.categories.map(\.kitValue))
        var terms: [String] = []

        // A region is honored only if the sentence actually names a place.
        // The model returns `international` or `vietnam` for requests that
        // named neither, and a wrong region is a real loss: `international`
        // hides every Vietnamese row, a third of the index. The source text is
        // the ground truth here and it costs nothing to consult.
        let region = AxisVocabulary.mentionsAPlace(text) ? generated.region.kitValue : nil

        if let raw = generated.eventName {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = name.lowercased()
            if AxisVocabulary.vietnamNames.contains(normalized)
                || AxisVocabulary.categories[normalized] != nil {
                // A place or a category filed as an event name is already
                // captured by its own axis, so it adds nothing here.
                if let named = AxisVocabulary.categories[normalized] {
                    categories.insert(named)
                }
            } else if !name.isEmpty {
                // Into the RANKING channel, never a gate. This is the one rule
                // that keeps a blank list impossible: the model invents this
                // string, and an invented string appears in no title, so
                // gating on it would erase every correctly-matched row. As a
                // term it lifts genuine brand matches to the top and costs
                // nothing when it is noise, and the fuzzy matcher now forgives
                // the model's spelling of a brand as readily as a person's.
                terms = name.split(whereSeparator: \.isWhitespace).map(String.init)
            }
        }

        // A relative window rather than the absolute pair this used to build,
        // so the whole query survives a round trip through the search field as
        // `deadline:30d` and cannot go stale overnight.
        let days = generated.withinDays.flatMap { $0 > 0 ? $0 : nil }

        self.init(
            categories: categories,
            regions: region.map { [$0] } ?? [],
            withinDays: days,
            terms: terms)
    }
}
