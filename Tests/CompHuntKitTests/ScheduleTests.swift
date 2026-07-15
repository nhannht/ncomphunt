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

@Suite struct NextUpcoming {
    @Test func picksSoonestFutureByRelevantDate() {
        let items = [
            comp("far", start: now.addingTimeInterval(3 * 86_400)),
            comp("soon", start: now.addingTimeInterval(2 * 3_600)),
            comp("mid", start: now.addingTimeInterval(86_400)),
        ]
        #expect(nextUpcoming(in: items, category: nil, region: nil, now: now)?.title == "soon")
    }

    @Test func registrationDeadlineBeatsStartDate() {
        // nextRelevantDate prefers the registration deadline.
        let item = comp("reg", start: now.addingTimeInterval(10 * 86_400),
                        deadline: now.addingTimeInterval(3_600))
        let later = comp("later", start: now.addingTimeInterval(2 * 3_600))
        #expect(nextUpcoming(in: [later, item], category: nil, region: nil, now: now)?.title == "reg")
    }

    @Test func excludesPastAndEndedAndOngoing() {
        let past = comp("past", start: now.addingTimeInterval(-3_600))
        let ended = comp("ended", start: now.addingTimeInterval(-2 * 86_400),
                         end: now.addingTimeInterval(-86_400))
        // Ongoing: started in the past, ends in the future -> nothing to count down to.
        let ongoing = comp("ongoing", start: now.addingTimeInterval(-3_600),
                           end: now.addingTimeInterval(3_600))
        #expect(nextUpcoming(in: [past, ended, ongoing], category: nil, region: nil, now: now) == nil)
    }

    @Test func categoryFilterSkipsSoonerOtherCategory() {
        let soonerAI = comp("ai", category: .ai, start: now.addingTimeInterval(3_600))
        let laterCTF = comp("ctf", category: .ctf, start: now.addingTimeInterval(2 * 3_600))
        #expect(nextUpcoming(in: [soonerAI, laterCTF], category: .ctf, region: nil, now: now)?.title == "ctf")
    }

    @Test func regionFilterSkipsSoonerOtherRegion() {
        let soonerGlobal = comp("g", region: .global, start: now.addingTimeInterval(3_600))
        let laterVN = comp("vn", region: .vietnam, start: now.addingTimeInterval(2 * 3_600))
        #expect(nextUpcoming(in: [soonerGlobal, laterVN], category: nil, region: .vietnam, now: now)?.title == "vn")
    }

    @Test func nilFiltersMeanAny() {
        let ai = comp("ai", category: .ai, region: .vietnam, start: now.addingTimeInterval(3_600))
        let ctf = comp("ctf", category: .ctf, region: .global, start: now.addingTimeInterval(2 * 3_600))
        #expect(nextUpcoming(in: [ai, ctf], category: nil, region: nil, now: now)?.title == "ai")
    }

    @Test func emptyWhenNoneMatch() {
        let ai = comp("ai", category: .ai, start: now.addingTimeInterval(3_600))
        #expect(nextUpcoming(in: [ai], category: .ctf, region: nil, now: now) == nil)
        #expect(nextUpcoming(in: [], category: nil, region: nil, now: now) == nil)
    }
}

@Suite struct CompactCountdown {
    @Test func formatsHoursAndMinutes() {
        #expect(compactCountdown(to: now.addingTimeInterval(2 * 3_600 + 14 * 60), now: now) == "2h14m")
    }

    @Test func formatsDaysAndHours() {
        #expect(compactCountdown(to: now.addingTimeInterval(3 * 86_400 + 4 * 3_600), now: now) == "3d4h")
    }

    @Test func dropsZeroTrailingUnit() {
        #expect(compactCountdown(to: now.addingTimeInterval(3 * 86_400), now: now) == "3d")
        #expect(compactCountdown(to: now.addingTimeInterval(3_600), now: now) == "1h")
    }

    @Test func formatsMinutesOnly() {
        #expect(compactCountdown(to: now.addingTimeInterval(45 * 60), now: now) == "45m")
        #expect(compactCountdown(to: now.addingTimeInterval(60), now: now) == "1m")
    }

    @Test func underOneMinuteAndPast() {
        #expect(compactCountdown(to: now.addingTimeInterval(30), now: now) == "<1m")
        #expect(compactCountdown(to: now.addingTimeInterval(-3_600), now: now) == "<1m")
    }
}

@Suite struct CategoryShortCode {
    @Test func codes() {
        #expect(CompetitionCategory.cp.shortCode == "CP")
        #expect(CompetitionCategory.ctf.shortCode == "CTF")
        #expect(CompetitionCategory.ai.shortCode == "AI")
        #expect(CompetitionCategory.hackathon.shortCode == "Hack")
        #expect(CompetitionCategory.design.shortCode == "Design")
        #expect(CompetitionCategory.other.shortCode == "")
    }
}
