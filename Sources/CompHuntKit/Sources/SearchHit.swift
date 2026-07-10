import Foundation

/// One raw web-search result before mapping into a CompetitionDTO.
struct SearchHit {
    let title: String
    let url: String
    let snippet: String
}

/// A query in the fixed catalog both search sources run.
public struct SearchQuery: Sendable {
    public let text: String
    /// Pre-classification: the query already names the category it hunts for.
    public let hint: CompetitionCategory?

    public init(text: String, hint: CompetitionCategory?) {
        self.text = text
        self.hint = hint
    }
}

public enum SearchCatalog {
    /// The fixed query set, with the current year injected so the catalog
    /// stays fresh without maintenance. Kept small on purpose: each refresh
    /// that includes search spends one API call per query per engine.
    public static func queries(now: Date = .now) -> [SearchQuery] {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        return [
            SearchQuery(text: "hackathon Vietnam \(year)", hint: .hackathon),
            SearchQuery(text: "\"cuộc thi\" lập trình \(year)", hint: .cp),
            SearchQuery(text: "CTF competition \(year) registration", hint: .ctf),
            SearchQuery(text: "AI competition \(year) deadline", hint: .ai),
            SearchQuery(text: "\"cuộc thi\" thiết kế \(year)", hint: .design),
            SearchQuery(text: "design contest \(year) deadline", hint: .design),
        ]
    }
}

/// Search hits are leads, not structured feed entries: no dates, arbitrary
/// pages. The mapper gates out obvious non-competitions before they reach
/// the store.
enum SearchHitMapper {
    /// Hosts a dedicated source already covers (its copies are richer),
    /// plus encyclopedic noise.
    static let excludedHosts: Set<String> = [
        "ctftime.org", "devpost.com", "ybox.vn", "clist.by",
        "contestwatchers.com", "wikipedia.org",
    ]

    /// A hit must smell like an actual competition announcement.
    static let competitionKeywords = [
        "cuộc thi", "competition", "contest", "hackathon", "ctf",
        "challenge", "olympiad", "olympic",
    ]

    static func dto(from hit: SearchHit, source: String, query: SearchQuery) -> CompetitionDTO? {
        guard let host = URL(string: hit.url)?.host?.lowercased() else { return nil }
        let bareHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let excluded = excludedHosts.contains { bareHost == $0 || bareHost.hasSuffix("." + $0) }
        guard !excluded else { return nil }

        let title = Text.plain(hit.title)
        let snippet = Text.plain(hit.snippet)
        let haystack = (title + " " + snippet).lowercased()
        guard competitionKeywords.contains(where: { haystack.contains($0) }) else { return nil }

        return CompetitionDTO(
            source: source,
            title: title,
            url: hit.url,
            category: query.hint,
            details: snippet,
            tags: ["search"])
    }
}
