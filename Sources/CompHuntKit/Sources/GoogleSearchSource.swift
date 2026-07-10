import Foundation

/// Google Programmable Search (Custom Search JSON API) over the fixed query
/// catalog. Requires GOOGLE_CSE_KEY plus GOOGLE_CSE_CX (a Programmable Search
/// Engine id with "search the entire web" enabled) in ~/.claude/secrets.yml.
/// Free tier is 100 queries/day; the catalog spends 6 per included refresh.
public struct GoogleSearchSource: CompetitionSource {
    public let name = "googlesearch"

    private let config: GoogleCSEConfig?

    public init(config: GoogleCSEConfig? = SecretsReader.googleCSE()) {
        self.config = config
    }

    public func fetch() async throws -> [CompetitionDTO] {
        guard let config else {
            throw SourceSkipped("Google CSE missing: set GOOGLE_CSE_KEY and "
                + "GOOGLE_CSE_CX in ~/.claude/secrets.yml")
        }
        var dtos: [CompetitionDTO] = []
        for query in SearchCatalog.queries() {
            var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
            components.queryItems = [
                URLQueryItem(name: "key", value: config.apiKey),
                URLQueryItem(name: "cx", value: config.engineID),
                URLQueryItem(name: "q", value: query.text),
                URLQueryItem(name: "num", value: "10"),
                URLQueryItem(name: "dateRestrict", value: "m1"),
            ]
            let data = try await HTTP.get(components.url!, headers: [
                "Accept": "application/json",
            ])
            dtos += try Self.parse(data, query: query)
        }
        return dtos
    }

    static func parse(_ data: Data, query: SearchQuery) throws -> [CompetitionDTO] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.items ?? []).compactMap { item in
            SearchHitMapper.dto(
                from: SearchHit(
                    title: item.title,
                    url: item.link,
                    snippet: item.snippet ?? ""),
                source: "googlesearch",
                query: query)
        }
    }

    private struct Response: Decodable {
        let items: [Item]?

        struct Item: Decodable {
            let title: String
            let link: String
            let snippet: String?
        }
    }
}
