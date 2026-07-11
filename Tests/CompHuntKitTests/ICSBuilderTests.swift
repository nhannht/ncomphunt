import Foundation
import Testing
@testable import CompHuntKit

@MainActor
@Suite struct ICSBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func competition(
        title: String = "Sample Contest",
        url: String = "https://example.com/contest",
        location: String = "",
        prize: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil
    ) -> Competition {
        let dto = CompetitionDTO(
            source: "fake", title: title, url: url, location: location,
            prize: prize, startDate: startDate, endDate: endDate,
            registrationDeadline: registrationDeadline)
        return Competition(dto: dto, category: .other, region: .global, now: now)
    }

    @Test func deadlineOnlyBecomesOneHourBlock() throws {
        let deadline = ISO8601DateFormatter().date(from: "2026-07-28T16:59:59Z")!
        let ics = try #require(ICSBuilder.calendar(
            for: competition(registrationDeadline: deadline), now: now))
        #expect(ics.contains("SUMMARY:Deadline: Sample Contest"))
        #expect(ics.contains("DTEND:20260728T165959Z"))
        #expect(ics.contains("DTSTART:20260728T155959Z"))
    }

    @Test func explicitDatesBoundTheEvent() throws {
        let start = ISO8601DateFormatter().date(from: "2026-08-01T09:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-08-03T18:00:00Z")!
        let ics = try #require(ICSBuilder.calendar(
            for: competition(startDate: start, endDate: end), now: now))
        #expect(ics.contains("SUMMARY:Sample Contest"))
        #expect(!ics.contains("SUMMARY:Deadline:"))
        #expect(ics.contains("DTSTART:20260801T090000Z"))
        #expect(ics.contains("DTEND:20260803T180000Z"))
    }

    @Test func datelessCompetitionHasNoEvent() {
        #expect(ICSBuilder.calendar(for: competition(), now: now) == nil)
    }

    @Test func embedsAlarmAndMetadata() throws {
        let deadline = Date(timeIntervalSince1970: 1_790_000_000)
        let ics = try #require(ICSBuilder.calendar(
            for: competition(location: "Hanoi", prize: "$1000", registrationDeadline: deadline),
            now: now))
        #expect(ics.contains("TRIGGER:-P1D"))
        #expect(ics.contains("LOCATION:Hanoi"))
        #expect(ics.contains("Prize: $1000"))
        #expect(ics.contains("UID:https://example.com/contest@ncomphunt"))
    }

    @Test func escapesTextValues() {
        #expect(ICSBuilder.escape("a,b;c\nd\\e") == #"a\,b\;c\nd\\e"#)
    }

    @Test func everyLineEndsWithCRLFAndFitsInBudget() throws {
        let longTitle = String(repeating: "Cuộc thi ", count: 30)
        let deadline = Date(timeIntervalSince1970: 1_790_000_000)
        let ics = try #require(ICSBuilder.calendar(
            for: competition(title: longTitle, registrationDeadline: deadline), now: now))
        #expect(!ics.contains("\n") || ics.replacingOccurrences(of: "\r\n", with: "").contains("\n") == false)
        for line in ics.components(separatedBy: "\r\n") {
            #expect(line.utf8.count <= 75)
        }
    }

    @Test func foldingPreservesContentOnUnfold() {
        let line = "DESCRIPTION:" + String(repeating: "một hai ba ", count: 40)
        let folded = ICSBuilder.fold(line)
        #expect(folded.count > 1)
        let unfolded = folded.first! + folded.dropFirst().map { String($0.dropFirst()) }.joined()
        #expect(unfolded == line)
        for piece in folded {
            #expect(piece.utf8.count <= 75)
        }
    }
}
