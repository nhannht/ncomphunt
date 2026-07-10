import Foundation

/// Devpost hackathon listings: https://devpost.com/api/hackathons
/// Public JSON endpoint, no auth. Category is decided by the classifier from
/// theme tags; the "devpost" tag makes plain listings fall through to .hackathon.
public struct DevpostSource: CompetitionSource {
    public let name = "devpost"

    private let pages: Int

    public init(pages: Int = 3) {
        self.pages = pages
    }

    public func fetch() async throws -> [CompetitionDTO] {
        var all: [CompetitionDTO] = []
        for page in 1...pages {
            let url = URL(string:
                "https://devpost.com/api/hackathons?status[]=upcoming&status[]=open&page=\(page)")!
            let data = try await HTTP.get(url, headers: ["Accept": "application/json"])
            let batch = try Self.parse(data)
            all += batch
            if batch.isEmpty { break }
        }
        return all
    }

    static func parse(_ data: Data) throws -> [CompetitionDTO] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.hackathons
            .filter { $0.openState != "ended" }
            .map { hackathon in
                let (start, end) = Self.parseSubmissionPeriod(hackathon.submissionPeriodDates ?? "")
                return CompetitionDTO(
                    source: "devpost",
                    title: hackathon.title,
                    organizer: hackathon.organizationName ?? "",
                    url: hackathon.url,
                    location: hackathon.displayedLocation?.location ?? "",
                    prize: Self.stripTags(hackathon.prizeAmount ?? ""),
                    details: hackathon.submissionPeriodDates.map { "Submissions: \($0)" } ?? "",
                    startDate: start,
                    endDate: end,
                    tags: (hackathon.themes ?? []).map(\.name) + ["devpost"]
                )
            }
    }

    /// "May 19 - Aug 17, 2026" or "Dec 20, 2025 - Jan 10, 2026" -> (start, end).
    /// Best effort: nil parts are fine, the UI falls back gracefully.
    static func parseSubmissionPeriod(_ text: String) -> (Date?, Date?) {
        let parts = text.components(separatedBy: " - ")
        guard parts.count == 2 else { return (nil, nil) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM d, yyyy"
        let end = formatter.date(from: parts[1])
        var start = formatter.date(from: parts[0])
        if start == nil, let end,
           let endYear = Calendar(identifier: .gregorian).dateComponents([.year], from: end).year {
            start = formatter.date(from: "\(parts[0]), \(endYear)")
            if let s = start, s > end {
                start = formatter.date(from: "\(parts[0]), \(endYear - 1)")
            }
        }
        return (start, end)
    }

    /// Devpost embeds markup in prize_amount ("$<span ...>2,000,000</span>").
    static func stripTags(_ html: String) -> String {
        Text.plain(html)
    }

    private struct Response: Decodable {
        let hackathons: [Hackathon]
    }

    private struct Hackathon: Decodable {
        struct DisplayedLocation: Decodable { let location: String? }
        struct Theme: Decodable { let name: String }

        let title: String
        let url: String
        let openState: String?
        let displayedLocation: DisplayedLocation?
        let submissionPeriodDates: String?
        let themes: [Theme]?
        let prizeAmount: String?
        let organizationName: String?

        enum CodingKeys: String, CodingKey {
            case title, url, themes
            case openState = "open_state"
            case displayedLocation = "displayed_location"
            case submissionPeriodDates = "submission_period_dates"
            case prizeAmount = "prize_amount"
            case organizationName = "organization_name"
        }
    }
}
