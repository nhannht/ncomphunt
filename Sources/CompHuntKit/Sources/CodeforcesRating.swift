import Foundation

/// Codeforces rating lookup: https://codeforces.com/api/user.info
///
/// Keyless, same as the `contest.list` call `CodeforcesSource` already
/// makes - verified against handle `tourist` (rating 3530 returned with no
/// credentials), so knowing the user's rating costs no new API key and no
/// new configuration. The rating is cached on `UserProfile` and refreshed on
/// the existing refresh cycle, never fetched on read; a failed lookup
/// degrades the FitScorer rating component to neutral and nothing else.
public enum CodeforcesRating {
    /// Current rating for a handle. An unrated account (no `rating` field in
    /// the response) reads as 0 - a real answer meaning "unrated", distinct
    /// from a failed lookup, which throws.
    public static func fetch(handle: String) async throws -> Int {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://codeforces.com/api/user.info")!
        components.queryItems = [URLQueryItem(name: "handles", value: trimmed)]
        let data = try await HTTP.get(components.url!)
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> Int {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.status == "OK", let user = response.result?.first else {
            throw CodeforcesError.apiFailed(response.comment ?? response.status)
        }
        return user.rating ?? 0
    }

    private struct Response: Decodable {
        let status: String
        let comment: String?
        let result: [User]?
    }

    private struct User: Decodable {
        /// Absent for accounts that never entered a rated round.
        let rating: Int?
    }
}
