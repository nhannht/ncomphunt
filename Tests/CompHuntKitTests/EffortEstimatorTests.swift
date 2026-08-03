import Foundation
import Testing
@testable import CompHuntKit

/// Fixtures per category, pinned on the shapes the live store actually
/// serves: 2-3h Codeforces rounds, 24-48h jeopardy CTFs, weekend and
/// multi-week hackathons, month-long AI contests, and the ybox lane's
/// deadline-driven writing and media contests.
@Suite struct EffortEstimatorTests {
    /// Fixed epoch so every wall is exact and no test touches the clock.
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func estimate(
        _ category: CompetitionCategory, wallHours: Double? = nil
    ) -> EffortEstimate {
        EffortEstimator.estimate(
            category: category,
            startDate: wallHours.map { _ in base },
            endDate: wallHours.map { base.addingTimeInterval($0 * 3600) })
    }

    // MARK: CP - the wall is the effort, except long challenges

    @Test func aTwoHourRoundCostsTwoHours() {
        let effort = estimate(.cp, wallHours: 2)
        #expect(effort.hours == 2...2)
        #expect(effort.confidence == .high)
        #expect(effort.midHours == 2)
    }

    /// CodeChef-style long challenge: 10 days of window is sessions of
    /// work, not 240 hours sat at a desk.
    @Test func aTenDayLongChallengeIsSessionsNotTheWindow() {
        let effort = estimate(.cp, wallHours: 240)
        #expect(effort.hours == 8...20)
        #expect(effort.confidence == .medium)
    }

    @Test func aDatelessRoundGetsTheTypicalBandAtLowConfidence() {
        let effort = estimate(.cp)
        #expect(effort.hours == 2...3)
        #expect(effort.confidence == .low)
    }

    // MARK: CTF - a slice of the window, never the window

    @Test func aFortyEightHourJeopardyIsASliceOfTheWall() {
        let effort = estimate(.ctf, wallHours: 48)
        #expect(effort.hours == 12...19)
        #expect(effort.hours.upperBound < 48)
        #expect(effort.confidence == .medium)
    }

    /// A week-long board must cap: nobody plays 67 hours of CTF. Both
    /// bounds, or the pair inverts into an invalid range and traps.
    @Test func aWeekLongCTFCapsBothBounds() {
        let effort = estimate(.ctf, wallHours: 168)
        #expect(effort.hours == 12...24)
    }

    // MARK: Hackathon - the wall length distinguishes the two formats

    @Test func aWeekendHackathonIsWakingHoursOfItsWall() {
        let effort = estimate(.hackathon, wallHours: 48)
        #expect(effort.hours == 19...29)
        #expect(effort.confidence == .high)
    }

    @Test func aMultiWeekAsyncHackathonIsACommittedBand() {
        let effort = estimate(.hackathon, wallHours: 24 * 21)
        #expect(effort.hours == 20...40)
        #expect(effort.confidence == .medium)
    }

    // MARK: AI - the COMP-14 headline case

    /// The acceptance criterion by name: a 4-week AI competition must not
    /// report its 672-hour wall.
    @Test func aFourWeekAIContestNeverReportsItsWall() {
        let effort = estimate(.ai, wallHours: 672)
        #expect(effort.hours == 20...60)
        #expect(effort.hours.upperBound < 672)
    }

    /// A 24h datathon is a fixed-window event whatever its topic.
    @Test func aShortDatathonReadsAsAFixedWindow() {
        let effort = estimate(.ai, wallHours: 24)
        #expect(effort.hours == 10...14)
        #expect(effort.confidence == .high)
    }

    // MARK: Deadline-driven lanes

    @Test func writingIsAModestFixedEffortWhateverTheWall() {
        // A ybox essay contest often has a month-long window; the essay
        // still costs the same handful of hours.
        #expect(estimate(.writing, wallHours: 720).hours == 3...10)
        #expect(estimate(.writing).hours == 3...10)
    }

    @Test func datesFirmUpConfidenceWithoutMovingTheBand() {
        let dated = estimate(.design, wallHours: 240)
        let dateless = estimate(.design)
        #expect(dated.hours == dateless.hours)
        #expect(dated.confidence == .medium)
        #expect(dateless.confidence == .low)
    }

    // MARK: Degradation and presentation

    /// Inverted dates are a source glitch, not a reason to trap or to trust.
    @Test func invertedDatesDegradeToTheCategoryDefault() {
        let effort = EffortEstimator.estimate(
            category: .ctf, startDate: base,
            endDate: base.addingTimeInterval(-3600))
        #expect(effort.hours == 6...16)
        #expect(effort.confidence == .low)
    }

    @Test func everyCategoryProducesABandWithoutDates() {
        for category in CompetitionCategory.allCases {
            let effort = EffortEstimator.estimate(
                category: category, startDate: nil, endDate: nil)
            #expect(effort.hours.lowerBound > 0)
            #expect(effort.confidence == .low)
            #expect(!effort.basis.isEmpty)
        }
    }

    @Test func hoursLabelCollapsesAPointBand() {
        #expect(estimate(.cp, wallHours: 3).hoursLabel == "3h")
        #expect(estimate(.ctf, wallHours: 48).hoursLabel == "12-19h")
    }
}
