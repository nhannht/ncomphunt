import Foundation

/// ybox.vn "Cuộc Thi" community: Vietnamese student and professional
/// competitions. The page is a client-rendered app, but the server embeds the
/// post list as JSON in `window.__INITIAL_STATE__`, so parsing is JSON
/// extraction, not HTML scraping.
public struct YboxSource: CompetitionSource {
    public let name = "ybox"

    public init() {}

    public func fetch() async throws -> [CompetitionDTO] {
        let url = URL(string: "https://ybox.vn/cuoc-thi")!
        let data = try await HTTP.get(url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SourceSkipped("ybox.vn returned non-UTF8 payload")
        }
        return try Self.parse(html: html)
    }

    /// Rails in preference order. The page embeds the same post in several
    /// rails and the "Recommended" ones serve slimmer copies and years-old
    /// posts, so the curated rails must win the in-batch dedupe.
    private static let railPriority = ["NewestPosts", "HighlightPosts", "SelectivePosts"]

    static func parse(html: String, now: Date = .now) throws -> [CompetitionDTO] {
        guard let json = extractInitialState(from: html) else {
            throw SourceSkipped("ybox.vn page no longer embeds __INITIAL_STATE__")
        }
        let state = try JSONDecoder().decode(State.self, from: json)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let groups = state.app.initialPosts
        let orderedRails = railPriority.filter { groups[$0] != nil }
            + groups.keys.filter { !railPriority.contains($0) }.sorted()

        var seenIDs = Set<String>()
        var dtos: [CompetitionDTO] = []
        for rail in orderedRails {
            for wrapped in groups[rail]?.edges ?? [] {
                guard let post = wrapped.value,
                      post.community?.url == "cuoc-thi",
                      post.deleted != true, post.active != false,
                      let title = post.title, !title.isEmpty,
                      // Moderated contest announcements always carry a
                      // deadline; member essays, results posts, and resurfaced
                      // 2017-era posts never do. Requiring it is the junk gate.
                      let deadline = post.deadline.flatMap({ iso.date(from: $0) }),
                      deadline >= now,
                      seenIDs.insert(post.id).inserted
                else { continue }
                dtos.append(CompetitionDTO(
                    source: "ybox",
                    title: title,
                    url: "https://ybox.vn/cuoc-thi/\(post.slug ?? post.id)",
                    details: post.summary ?? "",
                    registrationDeadline: deadline,
                    tags: ["ybox"]
                ))
            }
        }
        return dtos
    }

    /// Returns the balanced JSON object assigned to `window.__INITIAL_STATE__`.
    /// A brace scanner (string- and escape-aware) beats a regex here: the JSON
    /// itself may contain "};" inside string values.
    static func extractInitialState(from html: String) -> Data? {
        guard let marker = html.range(of: "window.__INITIAL_STATE__") else { return nil }
        guard let start = html[marker.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < html.endIndex {
            let character = html[index]
            if escaped {
                escaped = false
            } else if inString {
                if character == "\\" { escaped = true }
                if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return String(html[start...index]).data(using: .utf8)
                    }
                default: break
                }
            }
            index = html.index(after: index)
        }
        return nil
    }

    private struct State: Decodable {
        let app: App

        struct App: Decodable {
            let initialPosts: [String: PostGroup]
        }

        struct PostGroup: Decodable {
            let edges: [Failable<Post>]?
        }
    }

    /// One malformed post must not sink the whole payload.
    struct Failable<T: Decodable>: Decodable {
        let value: T?

        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct Post: Decodable {
        struct Community: Decodable { let url: String? }

        let id: String
        let title: String?
        let summary: String?
        let slug: String?
        let deadline: String?
        let community: Community?
        let active: Bool?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case title, summary, slug, deadline, community, active, deleted
        }
    }
}
