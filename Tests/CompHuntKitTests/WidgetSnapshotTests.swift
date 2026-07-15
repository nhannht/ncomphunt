import Foundation
import Testing
@testable import CompHuntKit

private let now = Date(timeIntervalSince1970: 1_000_000_000)

private func comp(
    _ title: String,
    category: CompetitionCategory = .ctf,
    region: Region = .global,
    start: Date? = nil,
    end: Date? = nil,
    deadline: Date? = nil,
    url: String? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: "test", title: title, url: url ?? "https://example.com/\(title)",
        startDate: start, endDate: end, registrationDeadline: deadline)
    return Competition(dto: dto, category: category, region: region)
}

@Suite struct UpcomingContests {
    @Test func sortsBySoonestRelevantDateAndCapsAtLimit() {
        let items = [
            comp("far", start: now.addingTimeInterval(3 * 86_400)),
            comp("soon", start: now.addingTimeInterval(2 * 3_600)),
            comp("mid", start: now.addingTimeInterval(86_400)),
        ]
        let titles = upcomingContests(in: items, category: nil, region: nil, limit: 2, now: now)
            .map(\.title)
        #expect(titles == ["soon", "mid"])
    }

    @Test func nilLimitReturnsAll() {
        let items = [
            comp("a", start: now.addingTimeInterval(3_600)),
            comp("b", start: now.addingTimeInterval(7_200)),
        ]
        #expect(upcomingContests(in: items, category: nil, region: nil, now: now).count == 2)
    }

    @Test func excludesPastEndedOngoingAndDateless() {
        let items = [
            comp("past", start: now.addingTimeInterval(-3_600)),
            comp("ended", start: now.addingTimeInterval(-2 * 86_400), end: now.addingTimeInterval(-86_400)),
            comp("ongoing", start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(3_600)),
            comp("dateless"),
            comp("future", start: now.addingTimeInterval(3_600)),
        ]
        let titles = upcomingContests(in: items, category: nil, region: nil, now: now).map(\.title)
        #expect(titles == ["future"])
    }

    @Test func filtersByCategoryAndRegion() {
        let items = [
            comp("ai-vn", category: .ai, region: .vietnam, start: now.addingTimeInterval(3_600)),
            comp("ctf-global", category: .ctf, region: .global, start: now.addingTimeInterval(7_200)),
        ]
        #expect(upcomingContests(in: items, category: .ctf, region: nil, now: now).map(\.title) == ["ctf-global"])
        #expect(upcomingContests(in: items, category: nil, region: .vietnam, now: now).map(\.title) == ["ai-vn"])
    }

    @Test func nextUpcomingIsTheFirst() {
        let items = [
            comp("later", start: now.addingTimeInterval(7_200)),
            comp("sooner", start: now.addingTimeInterval(3_600)),
        ]
        #expect(nextUpcoming(in: items, category: nil, region: nil, now: now)?.title == "sooner")
        #expect(nextUpcoming(in: [], category: nil, region: nil, now: now) == nil)
    }
}

@Suite struct WidgetSnapshotBuilder {
    @Test func mapsFieldsAndUsesShortCode() {
        let deadline = now.addingTimeInterval(3_600)
        let items = [
            comp("Some CTF", category: .ctf, deadline: deadline, url: "https://ex.com/ctf"),
        ]
        let snapshot = widgetSnapshot(from: items, now: now)
        let first = try! #require(snapshot.contests.first)
        #expect(first.title == "Some CTF")
        #expect(first.categoryCode == "CTF")
        #expect(first.url == "https://ex.com/ctf")
        #expect(first.date == deadline)
        #expect(first.key == items[0].key)
        #expect(snapshot.generatedAt == now)
    }

    @Test func capsAtLimitAcrossAllVerticals() {
        let items = (0..<10).map { index in
            comp("c\(index)", category: .ai, start: now.addingTimeInterval(Double(index + 1) * 3_600))
        }
        #expect(widgetSnapshot(from: items, limit: 6, now: now).contests.count == 6)
    }

    @Test func emptyWhenNothingUpcoming() {
        let items = [comp("past", start: now.addingTimeInterval(-3_600))]
        #expect(widgetSnapshot(from: items, now: now).contests.isEmpty)
    }

    @Test func codableRoundTrips() throws {
        let snapshot = WidgetSnapshot(generatedAt: now, contests: [
            WidgetContest(key: "k1", title: "T1", categoryCode: "CP", url: "https://x/1", date: now),
            WidgetContest(key: "k2", title: "T2", categoryCode: "AI", url: "https://x/2", date: nil),
        ])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }
}
