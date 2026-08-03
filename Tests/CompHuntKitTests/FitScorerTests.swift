import Foundation
import Testing
@testable import CompHuntKit

/// 1_800_000_000 sits at exactly 08:00 UTC, so every start-hour case below
/// can name its local clock time without touching the machine's zone.
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let vietnam = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

private func comp(
    _ title: String,
    tags: [CompetitionCategory] = [.cp],
    region: Region = .global,
    prize: String = "",
    start: Date? = nil,
    end: Date? = nil,
    deadline: Date? = nil
) -> Competition {
    let dto = CompetitionDTO(
        source: "test", title: title, url: "https://example.com/\(title)",
        location: "", prize: prize, details: "",
        startDate: start, endDate: end, registrationDeadline: deadline)
    return Competition(dto: dto, tags: tags, region: region)
}

private func profile(
    interests: [CompetitionCategory: Double] = [:],
    cfRating: Int? = nil,
    weeklyHours: Double = 10,
    prizeFloorUSD: Double = 0,
    preferredRegion: Region? = nil
) -> ProfileSnapshot {
    ProfileSnapshot(interests: interests, cfRating: cfRating,
                    weeklyHours: weeklyHours, prizeFloorUSD: prizeFloorUSD,
                    preferredRegion: preferredRegion, timezone: vietnam)
}

private func score(
    _ competition: Competition,
    _ snapshot: ProfileSnapshot = profile(),
    busy: [DateInterval] = []
) -> RankedCompetition {
    FitScorer.rank(competition, profile: snapshot, busy: busy, now: now)
}

/// Each component in isolation: it moves the score AND emits a reason -
/// the COMP-15 acceptance rule - and skips cleanly when its input is
/// missing rather than zeroing anything.
@Suite struct FitScorerComponentTests {
    @Test func anUntouchedProfileOnABareRowIsTheNeutralBase() {
        let verdict = score(comp("Mystery Contest", tags: [.other]))
        #expect(verdict.score == 50)
        #expect(verdict.headline == "Fair fit")
        #expect(verdict.reasons.isEmpty)
    }

    @Test func interestMovesWithTheWeightAndNamesTheTag() {
        let row = comp("SecurityFest CTF", tags: [.ctf])
        let loved = score(row, profile(interests: [.ctf: 1.0]))
        #expect(loved.score == 65)
        #expect(loved.reasons == ["CTF matches your interests"])
        let avoided = score(row, profile(interests: [.ctf: 0.0]))
        #expect(avoided.score == 35)
        #expect(avoided.reasons == ["CTF sits outside your interests"])
    }

    /// A multi-tag row scores by its best tag: loving AI is enough even
    /// when the row is also a hackathon.
    @Test func aMultiTagRowScoresByItsBestTag() {
        let row = comp("AI Buildathon", tags: [.hackathon, .ai])
        let verdict = score(row, profile(interests: [.ai: 1.0, .hackathon: 0.5]))
        #expect(verdict.score == 65)
        #expect(verdict.reasons == ["AI matches your interests"])
    }

    @Test func prizeFloorCutsBothWays() {
        // Same row both times so value density cancels and the 18-point
        // spread is the floor component alone.
        let row = comp("Floor Test", tags: [.other], prize: "$500")
        let above = score(row, profile(prizeFloorUSD: 100))
        let below = score(row, profile(prizeFloorUSD: 1000))
        #expect(above.reasons.contains("clears your $100 prize floor"))
        #expect(below.reasons.contains("below your $1000 prize floor"))
        #expect(above.score - below.score == 18)
        // No floor set: the component skips entirely.
        #expect(score(row).reasons.filter { $0.contains("floor") }.isEmpty)
    }

    @Test func valueDensityDividesPrizeByExpectedHours() {
        // $4,000 over a dateless CP round's 2-3h band is elite density.
        let verdict = score(comp("Prize Round", tags: [.cp], prize: "$4,000"))
        #expect(verdict.score == 64)
        #expect(verdict.reasons == ["≈ $4K for ~2-3h effort"])
    }

    @Test func effortFitsComparesTheBandToHoursBeforeTheDeadline() {
        // A dateless AI contest costs ~40h mid. Two weeks at 10h/week is
        // 20h: the wall is real and the reason says so.
        let row = comp("Kaggle-ish", tags: [.ai],
                       deadline: now.addingTimeInterval(14 * 86_400))
        let tight = score(row, profile(weeklyHours: 10))
        #expect(tight.reasons.contains("needs ~40h, you have ~20h before it starts"))
        let roomy = score(row, profile(weeklyHours: 40))
        #expect(roomy.reasons.contains("~40h fits your 40h/week"))
        #expect(roomy.score - tight.score == 18)
    }

    @Test func ratingBandMatchesAdjacentAndFar() {
        let snapshot = profile(cfRating: 1450) // Div 3 territory
        let match = score(comp("Codeforces Round 1024 (Div. 3)"), snapshot)
        #expect(match.reasons.contains("Div 3 matches your 1450 rating"))
        let adjacent = score(comp("Codeforces Round 1025 (Div. 2)"), snapshot)
        #expect(adjacent.reasons.contains("one division off your 1450 rating"))
        let far = score(comp("Codeforces Round 1026 (Div. 1)"), snapshot)
        #expect(far.reasons.contains("Div 1 is above your 1450 rating"))
        #expect(match.score > adjacent.score)
        #expect(adjacent.score > far.score)
    }

    /// Educational rounds are rated for Div 2 and below, so a 1450 belongs.
    @Test func educationalRoundsCountForLowerDivisions() {
        let verdict = score(
            comp("Educational Codeforces Round 182 (Rated for Div. 2)"),
            profile(cfRating: 1450))
        #expect(verdict.reasons.contains("Div 3 matches your 1450 rating"))
    }

    /// No rating, no Div in the title, or no cp tag: the component stays
    /// neutral instead of guessing.
    @Test func ratingBandSkipsWithoutItsInputs() {
        #expect(score(comp("Codeforces Global Round 30"),
                      profile(cfRating: 1450)).reasons.isEmpty)
        #expect(score(comp("Codeforces Round 1024 (Div. 3)")).reasons.isEmpty)
        #expect(score(comp("Div. 2 Essay Contest", tags: [.writing]),
                      profile(cfRating: 1450)).reasons.isEmpty)
    }

    @Test func startHourReadsTheProfileClock() {
        // 08:00 UTC the next day is 15:00 in Vietnam - sane.
        let sane = comp("Afternoon Round",
                        start: now.addingTimeInterval(86_400))
        #expect(score(sane).reasons.contains("starts 15:00 your time"))
        // 20:00 UTC is 03:00 in Vietnam - the raw date hides this cost.
        let brutal = comp("Night Owl Round",
                          start: now.addingTimeInterval(86_400 + 12 * 3600))
        #expect(score(brutal).reasons.contains("starts 03:00 your time"))
        #expect(score(sane).score > score(brutal).score)
    }

    @Test func regionPreferenceIsMildEitherWay() {
        let vn = comp("Olympiad", tags: [.academic], region: .vietnam)
        let global = comp("Olympiad", tags: [.academic], region: .global)
        let snapshot = profile(preferredRegion: .vietnam)
        #expect(score(vn, snapshot).reasons
            .contains("Vietnam contest, your preferred region"))
        #expect(score(global, snapshot).reasons
            .contains("outside your preferred region"))
        #expect(score(vn, snapshot).score - score(global, snapshot).score == 7)
        #expect(score(vn).reasons.isEmpty)
    }

    @Test func aDeadlineInsideThreeDaysAddsUrgency() {
        let soon = comp("Closing Soon", deadline: now.addingTimeInterval(48 * 3600))
        #expect(score(soon).reasons.contains("deadline in 2d"))
        let far = comp("Plenty of Time", deadline: now.addingTimeInterval(14 * 86_400))
        #expect(score(far).reasons.filter { $0.contains("deadline in") }.isEmpty)
    }

    @Test func aBusyIntervalOverTheWindowCostsTwelve() {
        let start = now.addingTimeInterval(86_400)
        let row = comp("Weekend CTF", tags: [.ctf],
                       start: start, end: start.addingTimeInterval(48 * 3600))
        let clash = [DateInterval(start: start.addingTimeInterval(3600),
                                  duration: 3600)]
        let free = score(row)
        let conflicted = score(row, busy: clash)
        #expect(conflicted.reasons.contains("conflicts with your calendar"))
        #expect(free.score - conflicted.score == 12)
        #expect(free.reasons.filter { $0.contains("calendar") }.isEmpty)
    }
}

@Suite struct FitScorerVerdictTests {
    /// The showcase case: everything a profile knows, agreeing.
    @Test func aRoundBuiltForThisPersonScoresStrong() {
        let start = now.addingTimeInterval(86_400) // tomorrow 15:00 VN
        let row = comp("Codeforces Round 1024 (Div. 3)",
                       start: start, end: start.addingTimeInterval(2 * 3600))
        let verdict = score(row, profile(interests: [.cp: 0.9], cfRating: 1450))
        // 50 +12 interest +10 div +6 effort-fits +4 urgency +3 start hour.
        #expect(verdict.score == 85)
        #expect(verdict.headline == "Strong fit")
        // Strongest first, and every non-zero component spoke.
        #expect(verdict.reasons == [
            "Competitive Programming matches your interests",
            "Div 3 matches your 1450 rating",
            "~2h fits your 10h/week",
            "deadline in 1d",
            "starts 15:00 your time",
        ])
    }

    @Test func theSameInputsAlwaysProduceTheSameVerdict() {
        let row = comp("Determinism Cup", tags: [.ai], prize: "$10,000",
                       deadline: now.addingTimeInterval(5 * 86_400))
        let snapshot = profile(interests: [.ai: 0.8], prizeFloorUSD: 100)
        #expect(score(row, snapshot) == score(row, snapshot))
    }

    @Test func scoresClampToTheBand() {
        // Pile every penalty on: outside interests, under floor, bad
        // density, effort wall, wrong region, 3am start.
        let start = now.addingTimeInterval(86_400 + 12 * 3600)
        let row = comp("Everything Wrong", tags: [.business], region: .vietnam,
                       prize: "$20", start: start,
                       deadline: now.addingTimeInterval(86_400))
        let verdict = score(row, profile(
            interests: [.business: 0.0], weeklyHours: 1,
            prizeFloorUSD: 500, preferredRegion: .global))
        #expect((0...100).contains(verdict.score))
        #expect(verdict.headline == "Weak fit")
        #expect(verdict.score < 30)
    }

    @Test func rankNeverTrapsOnGarbageRows() {
        let garbage = [
            comp(""),
            comp(String(repeating: "🏆", count: 500), tags: [.other]),
            comp("Inverted", start: now, end: now.addingTimeInterval(-3600)),
        ]
        for row in garbage {
            let verdict = score(row)
            #expect((0...100).contains(verdict.score))
        }
    }
}

@Suite struct FitScorerDivisionTests {
    @Test func titlesNameTheirDivisions() {
        #expect(FitScorer.divisions(in: "Codeforces Round 1024 (Div. 2)") == [2])
        #expect(FitScorer.divisions(in: "Codeforces Round 1030 (Div. 1 + Div. 2)") == [1, 2])
        #expect(FitScorer.divisions(in: "Codeforces Round (Division 4)") == [4])
        #expect(FitScorer.divisions(in: "Educational Codeforces Round 182") == [2, 3, 4])
        #expect(FitScorer.divisions(in: "Codeforces Global Round 30").isEmpty)
        #expect(FitScorer.divisions(in: "ICPC Asia Regional").isEmpty)
    }

    @Test func ratingsMapToTheirBands() {
        #expect(FitScorer.division(for: 2400) == 1)
        #expect(FitScorer.division(for: 1750) == 2)
        #expect(FitScorer.division(for: 1450) == 3)
        #expect(FitScorer.division(for: 900) == 4)
    }
}

/// Serialized: both tests mutate the process-wide context slots, and a
/// parallel interleaving would let one test's adoption leak into the other's
/// reads.
@Suite(.serialized) struct FitContextTests {
    /// The read-path conveniences score against whatever the app adopted.
    @Test func adoptedProfileDrivesTheConveniences() {
        let row = comp("Context CTF", tags: [.ctf])
        FitContext.adopt(ProfileSnapshot(interests: [.ctf: 1.0]))
        #expect(row.fitValue.score == 65)
        #expect(row.fitScoreForSort == 65)
        FitContext.adopt(.defaults)
        #expect(row.fitValue.score == 50)
    }

    /// Busy windows flow through their own slot into the same conveniences,
    /// so the sort comparator sees calendar conflicts too. One test for the
    /// same process-wide reason as above.
    @Test func adoptedBusyIntervalsReachTheConveniences() {
        let start = Date.now.addingTimeInterval(86_400)
        let row = comp("Busy Weekend CTF", tags: [.ctf],
                       start: start, end: start.addingTimeInterval(6 * 3600))
        let free = row.fitValue.score
        FitContext.adoptBusy([DateInterval(start: start, duration: 3600)])
        let conflicted = row.fitValue
        #expect(free - conflicted.score == 12)
        #expect(conflicted.reasons.contains("conflicts with your calendar"))
        FitContext.adoptBusy([])
        #expect(row.fitValue.score == free)
    }
}
