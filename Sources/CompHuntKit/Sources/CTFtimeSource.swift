import Foundation

/// CTFtime event calendar: https://ctftime.org/api/v1/events/
/// Public API, no auth; rejects non-browser user agents.
public struct CTFtimeSource: CompetitionSource {
    public let name = "ctftime"

    /// How far ahead to look for events.
    private let windowDays: Int

    public init(windowDays: Int = 120) {
        self.windowDays = windowDays
    }

    public func fetch() async throws -> [CompetitionDTO] {
        let now = Int(Date.now.timeIntervalSince1970)
        let finish = now + windowDays * 24 * 3600
        let url = URL(string:
            "https://ctftime.org/api/v1/events/?limit=100&start=\(now)&finish=\(finish)")!
        let data = try await HTTP.get(url)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> [CompetitionDTO] {
        let events = try JSONDecoder().decode([Event].self, from: data)
        let iso = ISO8601DateFormatter()
        return events.map { event in
            CompetitionDTO(
                source: "ctftime",
                title: event.title,
                organizer: event.organizers.map(\.name).joined(separator: ", "),
                url: event.ctftimeURL,
                category: .ctf,
                location: event.onsite ? event.location : "Online",
                prize: event.prizes.trimmingCharacters(in: .whitespacesAndNewlines),
                details: event.description,
                startDate: iso.date(from: event.start),
                endDate: iso.date(from: event.finish),
                tags: [event.format, event.restrictions].filter { !$0.isEmpty }
            )
        }
    }

    private struct Event: Decodable {
        struct Organizer: Decodable { let name: String }

        let title: String
        let ctftimeURL: String
        let start: String
        let finish: String
        let format: String
        let onsite: Bool
        let location: String
        let prizes: String
        let description: String
        let organizers: [Organizer]
        let restrictions: String

        enum CodingKeys: String, CodingKey {
            case title, start, finish, format, onsite, location, prizes,
                 description, organizers, restrictions
            case ctftimeURL = "ctftime_url"
        }
    }
}
