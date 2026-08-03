import Foundation
import Synchronization

/// A competition with a worth-it score attached.
///
/// `reasons` exists because an unexplained number is not actionable: "score
/// 87" alone is not trustworthy, while "≈ $670 for ~12-19h effort, Div 2
/// matches your 1450 rating" is. Every component that moved the score
/// contributes a reason, strongest first, positive or negative.
public struct RankedCompetition: Sendable, Equatable {
    /// 0-100. Comparable only against other scores from the same profile.
    public let score: Int
    /// One-line verdict band: "Strong fit", "Good fit", "Fair fit", "Weak fit".
    public let headline: String
    /// The factors behind the score, strongest first.
    public let reasons: [String]
}

/// The explainable fit score: profile + competition -> 0-100 with reasons.
///
/// Pure and deterministic like every engine here - the same inputs always
/// produce the same score, so the ranked list cannot reshuffle between
/// refreshes, and no model output may ever reach it (COMP-5). Nine
/// components each add a signed delta to a base of 50; a component whose
/// input is missing is SKIPPED, never zeroed, so a half-filled profile and
/// a dateless row both still rank usefully.
///
/// Calendar conflicts arrive as plain `[DateInterval]` computed in the app
/// layer (COMP-18), so EventKit never leaks in here and the scorer stays
/// testable; without calendar access the app adopts none and the component
/// skips - neutral, never an error.
public enum FitScorer {
    public static func rank(
        _ competition: Competition,
        profile: ProfileSnapshot,
        busy: [DateInterval] = [],
        now: Date = .now
    ) -> RankedCompetition {
        var moves: [(delta: Int, reason: String)] = []
        func apply(_ move: (Int, String)?) {
            guard let move, move.0 != 0 else { return }
            moves.append(move)
        }

        let prize = competition.prizeValue
        let effort = competition.effortEstimate

        apply(interest(competition, profile))
        apply(prizeFloor(prize, profile))
        apply(valueDensity(prize, effort))
        apply(effortFits(competition, effort, profile, now: now))
        apply(ratingBand(competition, profile))
        apply(startHour(competition, profile, now: now))
        apply(region(competition, profile))
        apply(urgency(competition, now: now))
        apply(calendarConflict(competition, busy))

        let score = max(0, min(100, 50 + moves.reduce(0) { $0 + $1.delta }))
        // Strongest first; equal magnitudes keep component order, which is
        // fixed, so the list is deterministic.
        let reasons = moves.sorted { abs($0.delta) > abs($1.delta) }.map(\.reason)
        return RankedCompetition(score: score,
                                 headline: headline(for: score),
                                 reasons: reasons)
    }

    private static func headline(for score: Int) -> String {
        switch score {
        case 75...: "Strong fit"
        case 60...: "Good fit"
        case 45...: "Fair fit"
        default: "Weak fit"
        }
    }

    // MARK: Components

    /// 1. Interest: the profile weight of the row's best-matching tag,
    /// centered on the neutral 0.5 - an untouched profile moves nothing.
    private static func interest(
        _ competition: Competition, _ profile: ProfileSnapshot
    ) -> (Int, String)? {
        let tags = competition.shownCategoryTags
        guard let best = tags.max(by: {
            (profile.interests[$0] ?? 0.5) < (profile.interests[$1] ?? 0.5)
        }) else { return nil }
        let weight = profile.interests[best] ?? 0.5
        let delta = Int(((weight - 0.5) * 30).rounded())
        guard delta != 0 else { return nil }
        return (delta, delta > 0
            ? "\(best.displayName) matches your interests"
            : "\(best.displayName) sits outside your interests")
    }

    /// 2. Prize against the profile's floor.
    private static func prizeFloor(
        _ prize: PrizeValue, _ profile: ProfileSnapshot
    ) -> (Int, String)? {
        guard profile.prizeFloorUSD > 0, let usd = prize.rankUSD else { return nil }
        let floor = Int(profile.prizeFloorUSD.rounded())
        return usd >= profile.prizeFloorUSD
            ? (8, "clears your $\(floor) prize floor")
            : (-10, "below your $\(floor) prize floor")
    }

    /// 3. Value density: dollars per expected hour. The whole reason
    /// EffortEstimator exists - prize alone ranks a 6-week grind above a
    /// 2-hour round.
    private static func valueDensity(
        _ prize: PrizeValue, _ effort: EffortEstimate
    ) -> (Int, String)? {
        guard let usd = prize.rankUSD, usd > 0, effort.midHours > 0 else { return nil }
        let rate = usd / effort.midHours
        let delta = switch rate {
        case 100...: 14
        case 25...: 8
        case 5...: 3
        default: -4
        }
        let label = prize.compactUSD ?? "$\(Int(usd.rounded()))"
        return (delta, "≈ \(label) for ~\(effort.hoursLabel) effort")
    }

    /// 4. Does the effort fit the hours the person actually has before the
    /// deadline. Judged against the band's midpoint: charitable enough to
    /// not punish a wide band, honest enough to flag a real wall.
    private static func effortFits(
        _ competition: Competition, _ effort: EffortEstimate,
        _ profile: ProfileSnapshot, now: Date
    ) -> (Int, String)? {
        guard profile.weeklyHours > 0,
              let anchor = competition.registrationDeadline ?? competition.startDate,
              anchor > now else { return nil }
        // Under a week still grants one week's hours: the deadline bounds
        // when you must COMMIT, not when the work is due.
        let weeks = max(anchor.timeIntervalSince(now) / 604_800, 1)
        let available = profile.weeklyHours * weeks
        let need = Int(effort.midHours.rounded())
        return available >= effort.midHours
            ? (6, "~\(need)h fits your \(Int(profile.weeklyHours))h/week")
            : (-12, "needs ~\(need)h, you have ~\(Int(available.rounded()))h before it starts")
    }

    /// 5. CP rating band: the Div in the title against the profile's cached
    /// Codeforces rating. Skips - stays neutral - without a rating, without
    /// a `.cp` tag, or when the title names no division (Global rounds are
    /// open to all, so silence is the honest answer there).
    private static func ratingBand(
        _ competition: Competition, _ profile: ProfileSnapshot
    ) -> (Int, String)? {
        guard let rating = profile.cfRating, rating > 0,
              competition.shownCategoryTags.contains(.cp) else { return nil }
        let divs = divisions(in: competition.title)
        guard !divs.isEmpty else { return nil }
        let mine = division(for: rating)
        if divs.contains(mine) {
            return (10, "Div \(mine) matches your \(rating) rating")
        }
        if divs.contains(where: { abs($0 - mine) == 1 }) {
            return (2, "one division off your \(rating) rating")
        }
        let nearest = divs.min(by: { abs($0 - mine) < abs($1 - mine) })!
        return (-8, nearest < mine
            ? "Div \(nearest) is above your \(rating) rating"
            : "Div \(nearest) is below your \(rating) rating")
    }

    /// 6. Start hour on the person's own clock. 08:00-22:59 is sane;
    /// a 3am round is a real cost the raw date hides.
    private static func startHour(
        _ competition: Competition, _ profile: ProfileSnapshot, now: Date
    ) -> (Int, String)? {
        guard let start = competition.startDate, start > now else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.timezone
        let parts = calendar.dateComponents([.hour, .minute], from: start)
        guard let hour = parts.hour, let minute = parts.minute else { return nil }
        let clock = String(format: "%02d:%02d", hour, minute)
        return (8...22).contains(hour)
            ? (3, "starts \(clock) your time")
            : (-6, "starts \(clock) your time")
    }

    /// 7. Region against the profile's preference. Mild either way: a
    /// global contest is still enterable from Vietnam and vice versa.
    private static func region(
        _ competition: Competition, _ profile: ProfileSnapshot
    ) -> (Int, String)? {
        guard let preferred = profile.preferredRegion else { return nil }
        return competition.region == preferred
            ? (5, "\(competition.region.displayName) contest, your preferred region")
            : (-2, "outside your preferred region")
    }

    /// 8. Urgency: a date inside 72h is worth surfacing before it is gone.
    private static func urgency(
        _ competition: Competition, now: Date
    ) -> (Int, String)? {
        guard let next = competition.nextRelevantDate, next > now,
              next.timeIntervalSince(now) <= 72 * 3600 else { return nil }
        return (4, "deadline in \(compactCountdown(to: next, now: now))")
    }

    /// 9. Calendar conflict against the busy windows the app layer read
    /// from EventKit (COMP-18). A conflict costs points and says so; it
    /// never hides a row.
    private static func calendarConflict(
        _ competition: Competition, _ busy: [DateInterval]
    ) -> (Int, String)? {
        guard !busy.isEmpty, let start = competition.startDate else { return nil }
        let end = competition.endDate ?? start.addingTimeInterval(2 * 3600)
        guard end > start else { return nil }
        let window = DateInterval(start: start, end: end)
        guard busy.contains(where: { $0.intersects(window) }) else { return nil }
        return (-12, "conflicts with your calendar")
    }

    // MARK: Codeforces divisions

    /// Divisions named in a round title: "Div. 2", "Div. 1 + Div. 2",
    /// "Division 3". "Educational" rounds are rated for Div 2 and below, so
    /// they read as 2, 3, and 4. An empty set means the title said nothing.
    static func divisions(in title: String) -> Set<Int> {
        let lowered = title.lowercased()
        var divs: Set<Int> = []
        if lowered.contains("educational") {
            divs.formUnion([2, 3, 4])
        }
        // Word scan, no regex: find "div"-family words and read the number
        // from the following token(s).
        let words = lowered.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for (index, word) in words.enumerated() where word == "div" || word == "division" {
            if index + 1 < words.count, let level = Int(words[index + 1]),
               (1...4).contains(level) {
                divs.insert(level)
            }
        }
        return divs
    }

    /// The division a rating typically competes in, per Codeforces bands:
    /// Div 1 from 1900, Div 2 from 1600, Div 3 from 1400, Div 4 below.
    static func division(for rating: Int) -> Int {
        switch rating {
        case 1900...: 1
        case 1600...: 2
        case 1400...: 3
        default: 4
        }
    }

    // MARK: The top pick (COMP-19)

    /// The best-fit upcoming competition and its verdict: what the menu bar
    /// counts down to and the widget features. Candidates are exactly the
    /// `upcomingContests` set the soonest-first surfaces already use, so the
    /// pick can never be an ended, ongoing, or dateless row; among them the
    /// highest score wins, ties break to the sooner date and then the title,
    /// keeping the choice deterministic. Pure - profile and busy are
    /// parameters, so tests need no process-wide context.
    public static func topPick(
        in competitions: [Competition],
        category: CompetitionCategory? = nil,
        region: Region? = nil,
        profile: ProfileSnapshot,
        busy: [DateInterval] = [],
        now: Date = .now
    ) -> (competition: Competition, fit: RankedCompetition)? {
        upcomingContests(in: competitions, category: category,
                         region: region, now: now)
            .map { (competition: $0,
                    fit: rank($0, profile: profile, busy: busy, now: now)) }
            .sorted { a, b in
                if a.fit.score != b.fit.score { return a.fit.score > b.fit.score }
                let aDate = a.competition.nextRelevantDate ?? .distantFuture
                let bDate = b.competition.nextRelevantDate ?? .distantFuture
                if aDate != bDate { return aDate < bDate }
                return a.competition.title < b.competition.title
            }
            .first
    }
}

/// The profile the read-path conveniences score against.
///
/// A process-wide slot rather than a parameter because the sort comparator
/// and the table's KeyPathComparator can only see the Competition - the same
/// shape as `PrizeNormalizer`'s cache. The app adopts a fresh snapshot
/// whenever the profile row changes, so a Settings edit re-ranks the list
/// without a relaunch; determinism holds because the score is a pure
/// function of (row, adopted snapshot).
public enum FitContext {
    private static let slot = Mutex<ProfileSnapshot>(.defaults)
    /// Busy windows read from the user's calendar (COMP-18). A second slot,
    /// not a ProfileSnapshot field: the profile is durable user input, the
    /// busy list is a volatile reading of the calendar, and they change on
    /// different clocks. Empty means no access or a free calendar - both
    /// score identically, which is the graceful-degradation rule.
    private static let busySlot = Mutex<[DateInterval]>([])

    public static func adopt(_ profile: ProfileSnapshot) {
        slot.withLock { $0 = profile }
    }

    public static var current: ProfileSnapshot {
        slot.withLock { $0 }
    }

    public static func adoptBusy(_ intervals: [DateInterval]) {
        busySlot.withLock { $0 = intervals }
    }

    public static var currentBusy: [DateInterval] {
        busySlot.withLock { $0 }
    }
}

extension Competition {
    /// The fit verdict for this row against the adopted profile. Computed on
    /// read: `PrizeNormalizer`'s memo already carries the expensive part and
    /// the rest is arithmetic, so a second cache would only add a staleness
    /// channel for refresh-updated rows.
    public var fitValue: RankedCompetition {
        FitScorer.rank(self, profile: FitContext.current,
                       busy: FitContext.currentBusy)
    }

    /// Comparator target for the Best fit sort and the table's Fit column.
    public var fitScoreForSort: Double {
        Double(fitValue.score)
    }
}
