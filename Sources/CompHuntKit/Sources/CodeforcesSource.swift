import Foundation

/// Codeforces contest list: https://codeforces.com/api/contest.list
/// Public API, no auth. Codeforces is the canonical competitive-programming
/// platform, so this keyless source guarantees the CP category is never empty
/// out of the box; clist.by (keyed) adds AtCoder/LeetCode/CodeChef breadth when
/// configured. Only upcoming rounds (phase == "BEFORE") are returned.
public struct CodeforcesSource: CompetitionSource {
    public let name = "codeforces"

    public init() {}

    public func fetch() async throws -> [CompetitionDTO] {
        let url = URL(string: "https://codeforces.com/api/contest.list?gym=false")!
        let data = try await HTTP.get(url)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> [CompetitionDTO] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.status == "OK" else {
            throw CodeforcesError.apiFailed(response.comment ?? response.status)
        }
        return response.result
            .filter { $0.phase == "BEFORE" }
            .map { contest in
                let start = contest.startTimeSeconds.map {
                    Date(timeIntervalSince1970: TimeInterval($0))
                }
                let end = contest.startTimeSeconds.map {
                    Date(timeIntervalSince1970: TimeInterval($0 + contest.durationSeconds))
                }
                return CompetitionDTO(
                    source: "codeforces",
                    title: contest.name,
                    organizer: "Codeforces",
                    url: "https://codeforces.com/contests/\(contest.id)",
                    category: .cp,
                    location: "Online",
                    details: "Host: Codeforces",
                    startDate: start,
                    endDate: end,
                    tags: ["codeforces", contest.type, "competitive programming"]
                )
            }
    }

    private struct Response: Decodable {
        let status: String
        let comment: String?
        let result: [Contest]
    }

    private struct Contest: Decodable {
        let id: Int
        let name: String
        let type: String
        let phase: String
        let durationSeconds: Int
        /// Absent for unscheduled contests; such rows carry no dates.
        let startTimeSeconds: Int?
    }
}

/// Raised when the Codeforces API answers with a non-OK status.
public struct CodeforcesError: Error, CustomStringConvertible {
    public let comment: String

    public static func apiFailed(_ comment: String) -> CodeforcesError {
        CodeforcesError(comment: comment)
    }

    public var description: String { "Codeforces API error: \(comment)" }
}
