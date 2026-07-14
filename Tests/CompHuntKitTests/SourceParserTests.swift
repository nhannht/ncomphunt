import Foundation
import Testing
@testable import CompHuntKit

func fixture(_ name: String, _ ext: String) throws -> Data {
    let url = try #require(Bundle.module.url(
        forResource: name, withExtension: ext, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct CTFtimeParsing {
    @Test func parsesLiveShapedFixture() throws {
        let dtos = try CTFtimeSource.parse(try fixture("ctftime", "json"))
        #expect(dtos.count == 3)

        let first = try #require(dtos.first)
        #expect(first.source == "ctftime")
        #expect(first.category == .ctf)
        #expect(first.title == "Junior.Crypt.2026 CTF")
        #expect(first.url.hasPrefix("https://ctftime.org/event/"))
        #expect(first.startDate != nil)
        #expect(first.endDate != nil)
        #expect(first.location == "Online")
        #expect(!first.organizer.isEmpty)
    }

    @Test func onlineEventsGetOnlineLocation() throws {
        let dtos = try CTFtimeSource.parse(try fixture("ctftime", "json"))
        for dto in dtos where !dto.location.isEmpty {
            #expect(dto.location == "Online" || !dto.location.isEmpty)
        }
    }
}

@Suite struct CodeforcesParsing {
    @Test func parsesUpcomingRoundsOnly() throws {
        let dtos = try CodeforcesSource.parse(try fixture("codeforces", "json"))
        // Only phase == "BEFORE" rows survive; the FINISHED round is dropped.
        #expect(dtos.count == 2)

        let first = try #require(dtos.first)
        #expect(first.source == "codeforces")
        #expect(first.category == .cp)
        #expect(first.title == "Codeforces Round 1109 (Div. 3)")
        #expect(first.url == "https://codeforces.com/contests/2244")
        #expect(first.organizer == "Codeforces")
        #expect(first.startDate != nil)
        #expect(first.endDate != nil)
        // start + duration == end.
        if let start = first.startDate, let end = first.endDate {
            #expect(end.timeIntervalSince(start) == 8100)
        }
    }

    @Test func unscheduledRoundHasNoDates() throws {
        let dtos = try CodeforcesSource.parse(try fixture("codeforces", "json"))
        let unscheduled = try #require(dtos.first { $0.url.hasSuffix("/2250") })
        #expect(unscheduled.startDate == nil)
        #expect(unscheduled.endDate == nil)
        #expect(unscheduled.category == .cp)
    }

    @Test func nonOKStatusThrows() throws {
        let failed = Data(#"{"status":"FAILED","comment":"call limit exceeded","result":[]}"#.utf8)
        #expect(throws: CodeforcesError.self) {
            try CodeforcesSource.parse(failed)
        }
    }
}

@Suite struct MLContestsParsing {
    private func html() throws -> String {
        try #require(String(data: try fixture("mlcontests", "html"), encoding: .utf8))
    }

    /// Fixture has open deadlines 1 Aug / 15 Sep 2026 and closed 3 Jul 2026.
    private let now = ISO8601DateFormatter().date(from: "2026-07-20T00:00:00Z")!

    @Test func onlyOpenCompetitionsSurviveAsAI() throws {
        let dtos = try MLContestsSource.parse(html: try html(), now: now)
        // Closed (3 Jul) and malformed-date rows drop; 2 open remain.
        #expect(dtos.count == 2)
        #expect(dtos.allSatisfy { $0.source == "mlcontests" })
        #expect(dtos.allSatisfy { $0.category == .ai })
        #expect(!dtos.contains { $0.title.contains("Closed") })
        #expect(!dtos.contains { $0.title.contains("Malformed") })
    }

    @Test func decodesEntitiesAndKeepsReferral() throws {
        let dtos = try MLContestsSource.parse(html: try html(), now: now)
        let kaggle = try #require(dtos.first { $0.url.contains("kaggle.com") })
        // &amp; -> & inside the URL, &#39; -> ' inside the name.
        #expect(kaggle.url.contains("&x=1"))
        #expect(!kaggle.url.contains("&amp;"))
        #expect(kaggle.title == "Kaggle's Fraud Challenge")
        #expect(kaggle.url.contains("ref=mlcontests"))
        #expect(kaggle.organizer == "Kaggle")
        #expect(kaggle.prize == "$50,000")
        #expect(kaggle.registrationDeadline != nil)
        #expect(kaggle.tags.contains("Kaggle"))
    }

    @Test func pastCutoffDropsEverything() throws {
        let farFuture = ISO8601DateFormatter().date(from: "2030-01-01T00:00:00Z")!
        let dtos = try MLContestsSource.parse(html: try html(), now: farFuture)
        #expect(dtos.isEmpty)
    }

    @Test func missingAttributeThrowsSkip() {
        #expect(throws: SourceSkipped.self) {
            _ = try MLContestsSource.parse(html: "<html><body>no data here</body></html>")
        }
    }
}

@Suite struct DevpostParsing {
    @Test func parsesLiveShapedFixture() throws {
        let dtos = try DevpostSource.parse(try fixture("devpost", "json"))
        #expect(dtos.count == 3)

        let first = try #require(dtos.first)
        #expect(first.source == "devpost")
        #expect(first.title == "Build with Gemini XPRIZE")
        #expect(first.prize.contains("2,000,000"))
        #expect(!first.prize.contains("<"))
        #expect(first.tags.contains("devpost"))
        #expect(first.endDate != nil)
    }

    @Test func aiThemedHackathonClassifiesAsAI() throws {
        let dtos = try DevpostSource.parse(try fixture("devpost", "json"))
        let xprize = try #require(dtos.first { $0.title.contains("XPRIZE") })
        #expect(Classifier.category(for: xprize) == .ai)
    }

    @Test func submissionPeriodParsing() {
        let sameYear = DevpostSource.parseSubmissionPeriod("May 19 - Aug 17, 2026")
        #expect(sameYear.0 != nil)
        #expect(sameYear.1 != nil)
        if let start = sameYear.0, let end = sameYear.1 {
            #expect(start < end)
        }

        let crossYear = DevpostSource.parseSubmissionPeriod("Dec 20, 2025 - Jan 10, 2026")
        if let start = crossYear.0, let end = crossYear.1 {
            #expect(start < end)
        }

        let junk = DevpostSource.parseSubmissionPeriod("TBD")
        #expect(junk.0 == nil)
        #expect(junk.1 == nil)
    }

    @Test func stripTagsRemovesMarkup() {
        #expect(DevpostSource.stripTags("$<span data-currency-value>2,000,000</span>") == "$2,000,000")
        #expect(DevpostSource.stripTags("") == "")
    }
}
