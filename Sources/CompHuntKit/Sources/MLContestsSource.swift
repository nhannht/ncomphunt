import Foundation

/// MLContests.com: a directory of machine-learning competitions across Kaggle,
/// Zindi, Codabench, Hugging Face, DrivenData, AIcrowd, EvalAI, Grand Challenge
/// and more. The homepage embeds the whole list as an HTML-entity-encoded JSON
/// array in a `data-competitions="..."` attribute, so parsing is JSON extraction
/// (ybox pattern), not HTML scraping. Keyless, and the "CTFtime of AI": one fetch
/// puts Kaggle and its peers in the app with no per-platform token.
///
/// The payload is a multi-year archive; only competitions whose deadline is
/// today-or-future are emitted, so the store never fills with closed rows (which,
/// being dated, `CompetitionStore.prune` would never reclaim).
public struct MLContestsSource: CompetitionSource {
    public let name = "mlcontests"

    public init() {}

    public func fetch() async throws -> [CompetitionDTO] {
        let url = URL(string: "https://mlcontests.com/")!
        let data = try await HTTP.get(url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SourceSkipped("mlcontests.com returned non-UTF8 payload")
        }
        return try Self.parse(html: html)
    }

    static func parse(html: String, now: Date = .now) throws -> [CompetitionDTO] {
        guard let json = extractCompetitionsJSON(from: html) else {
            throw SourceSkipped("mlcontests.com page no longer embeds data-competitions")
        }
        let rows = try JSONDecoder().decode([Failable<Competition>].self, from: json)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM yyyy"

        var dtos: [CompetitionDTO] = []
        for wrapped in rows {
            guard let competition = wrapped.value,
                  !competition.name.isEmpty, !competition.url.isEmpty,
                  // Every listed comp carries a deadline; requiring a future one
                  // is what drops the years of closed archive entries.
                  let deadline = parseDeadline(competition.deadline, formatter),
                  deadline >= now
            else { continue }
            let platform = competition.platform ?? ""
            var details = platform.isEmpty ? "" : "Platform: \(platform)"
            if let sponsor = competition.sponsor, !sponsor.isEmpty {
                details += details.isEmpty ? "Sponsor: \(sponsor)" : " · Sponsor: \(sponsor)"
            }
            dtos.append(CompetitionDTO(
                source: "mlcontests",
                title: competition.name,
                organizer: platform,
                // Keep the ?ref=mlcontests referral (courtesy to the free source);
                // the dedupe key strips the query string anyway.
                url: competition.url,
                category: .ai,
                prize: competition.prize ?? "",
                details: details,
                registrationDeadline: deadline,
                tags: (competition.tags ?? []) + [platform].filter { !$0.isEmpty }
            ))
        }
        return dtos
    }

    /// Deadlines are `d MMM yyyy` (e.g. "1 Aug 2026"). One archive row is
    /// malformed ("11 May 2026 Apr 2026"); take the first three tokens so a
    /// stray suffix can't turn a real date into a nil that silently drops a row.
    static func parseDeadline(_ raw: String?, _ formatter: DateFormatter) -> Date? {
        guard let raw else { return nil }
        let tokens = raw.split(separator: " ")
        guard tokens.count >= 3 else { return nil }
        return formatter.date(from: tokens.prefix(3).joined(separator: " "))
    }

    /// Returns the JSON array assigned to the `data-competitions` attribute.
    /// The attribute's inner quotes are `&#34;`, so no raw `"` appears until the
    /// closing quote; a substring beats a brace scanner here.
    static func extractCompetitionsJSON(from html: String) -> Data? {
        guard let marker = html.range(of: "data-competitions=\"") else { return nil }
        let rest = html[marker.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let encoded = String(rest[..<end])
        // The blob is dominated by &#34; (JSON quotes). Replacing that one in a
        // single pass first avoids Text.decodeEntities' per-entity rescan loop
        // running thousands of times over a ~230KB string; the helper then
        // handles the remaining named and numeric entities (&amp;, &#39;, ...).
        let quotesDecoded = encoded.replacingOccurrences(of: "&#34;", with: "\"")
        return Text.decodeEntities(quotesDecoded).data(using: .utf8)
    }

    /// One malformed row must not sink the whole array.
    struct Failable<T: Decodable>: Decodable {
        let value: T?

        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct Competition: Decodable {
        let name: String
        let url: String
        let platform: String?
        let tags: [String]?
        let prize: String?
        let sponsor: String?
        let deadline: String?
    }
}
