import Foundation

/// Brave Web Search API over the fixed query catalog. Requires a free API key
/// (BRAVE_API_KEY in ~/.claude/secrets.yml, plan at brave.com/search/api).
/// Results are leads: freshness-limited to the past month, gated by
/// SearchHitMapper, and carry no dates.
public struct BraveSearchSource: CompetitionSource {
    public let name = "brave"

    private let apiKey: String?

    public init(apiKey: String? = SecretsReader.braveKey()) {
        self.apiKey = apiKey
    }

    public func fetch() async throws -> [CompetitionDTO] {
        guard let apiKey else {
            throw SourceSkipped("Brave key missing: set BRAVE_API_KEY in "
                + "~/.claude/secrets.yml (free plan at brave.com/search/api)")
        }
        var dtos: [CompetitionDTO] = []
        let queries = SearchCatalog.queries()
        for (index, query) in queries.enumerated() {
            var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search")!
            components.queryItems = [
                URLQueryItem(name: "q", value: query.text),
                URLQueryItem(name: "count", value: "20"),
                URLQueryItem(name: "freshness", value: "pm"),
            ]
            let data = try await HTTP.get(components.url!, headers: [
                "X-Subscription-Token": apiKey,
                "Accept": "application/json",
            ])
            dtos += try Self.parse(data, query: query)
            // Free plan allows 1 request/second.
            if index < queries.count - 1 {
                try? await Task.sleep(for: .seconds(1.1))
            }
        }
        return dtos
    }

    static func parse(_ data: Data, query: SearchQuery) throws -> [CompetitionDTO] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.web?.results ?? []).compactMap { result in
            SearchHitMapper.dto(
                from: SearchHit(
                    title: result.title,
                    url: result.url,
                    snippet: result.description ?? ""),
                source: "brave",
                query: query)
        }
    }

    private struct Response: Decodable {
        let web: Web?

        struct Web: Decodable {
            let results: [Result]
        }

        struct Result: Decodable {
            let title: String
            let url: String
            let description: String?
        }
    }
}
