import Foundation

/// Raised by a source that cannot run in the current environment (e.g. missing
/// credentials). The engine logs it as a skip, not a failure.
public struct SourceSkipped: Error, CustomStringConvertible {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}

/// clist.by API v4 aggregator: one call covers Codeforces, AtCoder, LeetCode,
/// CodeChef, Kaggle, HackerRank and hundreds more. Requires a free API key
/// (CLIST_USERNAME / CLIST_API_KEY in ~/.claude/secrets.yml). Events hosted on
/// ctftime.org are skipped: the direct CTFtime source carries richer fields.
public struct ClistSource: CompetitionSource {
    public let name = "clist"

    private let credentials: ClistCredentials?
    private let windowDays: Int

    public init(credentials: ClistCredentials? = SecretsReader.clistCredentials(),
                windowDays: Int = 60) {
        self.credentials = credentials
        self.windowDays = windowDays
    }

    public func fetch() async throws -> [CompetitionDTO] {
        guard let credentials else {
            throw SourceSkipped("clist.by credentials missing: set CLIST_USERNAME and "
                + "CLIST_API_KEY in ~/.claude/secrets.yml (free key at clist.by)")
        }
        var components = URLComponents(string: "https://clist.by/api/v4/contest/")!
        components.queryItems = [
            URLQueryItem(name: "upcoming", value: "true"),
            URLQueryItem(name: "start_time__during", value: "\(windowDays) days"),
            URLQueryItem(name: "order_by", value: "start"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        let data = try await HTTP.get(components.url!, headers: [
            "Authorization": "ApiKey \(credentials.username):\(credentials.apiKey)",
            "Accept": "application/json",
        ])
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> [CompetitionDTO] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return response.objects
            .filter { $0.resourceName != "ctftime.org" }
            .map { contest in
                CompetitionDTO(
                    source: "clist",
                    title: contest.event,
                    organizer: contest.resourceName,
                    url: contest.href,
                    details: "Host: \(contest.resourceName)",
                    startDate: contest.start.flatMap { formatter.date(from: $0) },
                    endDate: contest.end.flatMap { formatter.date(from: $0) },
                    tags: [contest.resourceName, "clist"]
                )
            }
    }

    private struct Response: Decodable {
        let objects: [Contest]
    }

    private struct Contest: Decodable {
        let event: String
        let href: String
        let start: String?
        let end: String?
        let resourceName: String

        enum CodingKeys: String, CodingKey {
            case event, href, start, end, resource
        }

        /// v4 serializes `resource` as a plain name string; older payloads used
        /// an object with a `name` field. Accept both.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            event = try container.decode(String.self, forKey: .event)
            href = try container.decode(String.self, forKey: .href)
            start = try container.decodeIfPresent(String.self, forKey: .start)
            end = try container.decodeIfPresent(String.self, forKey: .end)
            if let name = try? container.decode(String.self, forKey: .resource) {
                resourceName = name
            } else if let object = try? container.decode([String: String].self, forKey: .resource),
                      let name = object["name"] {
                resourceName = name
            } else {
                resourceName = ""
            }
        }
    }
}
