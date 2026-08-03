import Foundation

/// Expected human effort for a competition, as a range of hours.
///
/// A range rather than a point because a point would be a lie twice over:
/// nobody knows the true cost, and a single number invites the reader to
/// trust it. `basis` says where the band came from, and feeds `FitScorer`
/// reasons so "costs about 40 hours" always arrives with its why.
public struct EffortEstimate: Sendable, Equatable {
    public enum Confidence: Sendable, Equatable {
        case high
        case medium
        /// The inputs were thin - typically no dates - and the band is a
        /// category default. Honestly low, per the COMP-14 acceptance rule.
        case low
    }

    public var hours: ClosedRange<Double>
    public var confidence: Confidence
    /// Short human string naming the heuristic that produced the band.
    public var basis: String

    /// Midpoint, the value-density denominator (`topPrizeUSD / midHours`).
    public var midHours: Double {
        (hours.lowerBound + hours.upperBound) / 2
    }

    /// "12-19h", or "3h" when the band collapses to a point. Whole hours:
    /// pretending to sub-hour precision would oversell the estimate.
    public var hoursLabel: String {
        let low = Int(hours.lowerBound.rounded())
        let high = Int(hours.upperBound.rounded())
        return low == high ? "\(low)h" : "\(low)-\(high)h"
    }
}

/// Expected hours from duration and category - the effort denominator that
/// keeps prize money from ranking a 6-week Kaggle above a 2-hour round.
///
/// Pure and deterministic like `Classifier` and `PrizeNormalizer`: static
/// tables, no model, no clock. The central trap this exists to avoid is
/// wall-versus-effort confusion - a 4-week AI competition is NOT 672 hours
/// of work, and a 48-hour jeopardy CTF is not 48 hours of playing.
public enum EffortEstimator {
    /// The band for a competition. Missing or inverted dates degrade to the
    /// category default at `.low` confidence rather than to nil, so dateless
    /// rows still rank (COMP-14 constraint).
    public static func estimate(
        category: CompetitionCategory,
        startDate: Date?,
        endDate: Date?
    ) -> EffortEstimate {
        let wallHours = wall(startDate: startDate, endDate: endDate)
        switch category {
        case .cp:
            guard let wall = wallHours else {
                return .init(hours: 2...3, confidence: .low,
                             basis: "typical round length")
            }
            // A round is sat start to finish, so the wall IS the effort -
            // but only for round-shaped walls. CodeChef-style long
            // challenges span days, and there the window is mostly not
            // being worked.
            if wall <= 6 {
                let clamped = max(1, wall)
                return .init(hours: clamped...clamped, confidence: .high,
                             basis: "\(Int(clamped.rounded()))h round, the wall is the effort")
            }
            return .init(hours: 8...20, confidence: .medium,
                         basis: "long-format challenge, effort is sessions not the window")
        case .ctf:
            guard let wall = wallHours else {
                return .init(hours: 6...16, confidence: .low,
                             basis: "typical jeopardy effort")
            }
            // Jeopardy events run 24-48h wall (some a week), but a player
            // works a slice of it: sleep, other life, and solved-out
            // categories all eat the window. A quarter to 40%, both bounds
            // capped so a week-long board does not read as a week of work -
            // and so the pair can never invert into an invalid range.
            let low = max(2, min(wall * 0.25, 12))
            let high = min(max(wall * 0.4, low), 24)
            return .init(hours: band(low, high), confidence: .medium,
                         basis: "\(Int(wall.rounded()))h window, realistic effort is a slice of it")
        case .hackathon:
            guard let wall = wallHours else {
                return .init(hours: 20...40, confidence: .low,
                             basis: "typical hackathon commitment")
            }
            if wall <= 96 {
                // Fixed-window event: the wall minus sleep is the effort.
                return .init(hours: band(wall * 0.4, wall * 0.6), confidence: .high,
                             basis: "\(Int(wall.rounded()))h fixed window, waking hours only")
            }
            return .init(hours: 20...40, confidence: .medium,
                         basis: "multi-week submission window, effort is the build not the wait")
        case .ai:
            guard let wall = wallHours else {
                return .init(hours: 20...60, confidence: .low,
                             basis: "typical committed band for an ML contest")
            }
            if wall <= 96 {
                // A datathon is a fixed-window event, whatever its topic.
                return .init(hours: band(wall * 0.4, wall * 0.6), confidence: .high,
                             basis: "\(Int(wall.rounded()))h fixed window, waking hours only")
            }
            // Multi-week: effort is user-chosen, so a committed band with a
            // cap - the 4-week contest must never report its 672-hour wall.
            return .init(hours: 20...60, confidence: .medium,
                         basis: "multi-week contest, committed band capped")
        case .design:
            return deadlineDriven(4...12, dated: wallHours != nil,
                                  what: "a design entry")
        case .writing:
            return deadlineDriven(3...10, dated: wallHours != nil,
                                  what: "an essay or article")
        case .media:
            return deadlineDriven(6...20, dated: wallHours != nil,
                                  what: "a photo, video, or performance entry")
        case .business:
            return deadlineDriven(10...30, dated: wallHours != nil,
                                  what: "a case or pitch deck")
        case .academic:
            return deadlineDriven(3...10, dated: wallHours != nil,
                                  what: "a quiz, exam, or speech")
        case .other:
            return .init(hours: 5...20, confidence: .low,
                         basis: "unclassified, broad default")
        }
    }

    /// Computed bounds rounded to whole hours - sub-hour precision on an
    /// estimate would be a claim the heuristic cannot back - and re-ordered
    /// so a rounding tie can never invert the range.
    private static func band(_ low: Double, _ high: Double) -> ClosedRange<Double> {
        let a = low.rounded()
        let b = high.rounded()
        return min(a, b)...max(a, b)
    }

    /// Wall-clock hours between the dates, or nil when either is missing or
    /// the pair is inverted (source glitches happen; garbage in, default out).
    private static func wall(startDate: Date?, endDate: Date?) -> Double? {
        guard let startDate, let endDate, endDate > startDate else { return nil }
        return endDate.timeIntervalSince(startDate) / 3600
    }

    /// Submission-deadline categories: the wall is mostly waiting, so the
    /// band is a fixed per-category effort and dates only firm up confidence.
    private static func deadlineDriven(
        _ hours: ClosedRange<Double>, dated: Bool, what: String
    ) -> EffortEstimate {
        EffortEstimate(hours: hours,
                       confidence: dated ? .medium : .low,
                       basis: "deadline-driven, \(what) is the effort")
    }
}

extension Competition {
    /// The band for this row, from its leading category and dates.
    public var effortEstimate: EffortEstimate {
        EffortEstimator.estimate(category: category,
                                 startDate: startDate,
                                 endDate: endDate)
    }
}
