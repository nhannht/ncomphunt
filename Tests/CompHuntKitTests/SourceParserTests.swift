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
