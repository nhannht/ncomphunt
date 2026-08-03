import Foundation
import SwiftData

/// The person the fit score is scored FOR: interest weights, rating, hours,
/// and floor. One row, created lazily, edited from Settings.
///
/// Its own `@Model` and critically NOT columns on `Competition` - that model
/// is a rebuildable cache whose rows `CompetitionStore.prune` deletes, and a
/// profile stored there would be silently wiped by a prune or a store
/// rebuild. Added in schema V4; see `CompetitionSchema.swift`.
///
/// Deliberately absent, diverging from the COMP-16 spec as written:
/// free-text skills and a solo/team preference (no `FitScorer` component
/// consumes either - a field the score never reads is dead UI), and a
/// persisted timezone (the system's `TimeZone.current` is the honest value;
/// a stored copy could only drift from it).
@Model
public final class UserProfile {
    /// Interest weights, comma-joined `category:weight` pairs in category
    /// declaration order ("cp:0.8,ctf:0.5") - the same raw-string idiom as
    /// `categoryTagsRaw`. Absent category means "never set", which reads as
    /// the neutral 0.5.
    public var interestsRaw: String = ""
    /// Codeforces handle; empty means the rating component stays neutral.
    public var cfHandle: String = ""
    /// Cached rating for `cfHandle`, refreshed on the refresh cycle
    /// (COMP-17), never fetched on read.
    public var cfRating: Int?
    public var cfRatingUpdated: Date?
    /// Hours per week the person can actually give a competition.
    public var weeklyHours: Double = 10
    /// Prizes below this stop being interesting; 0 means no floor.
    public var prizeFloorUSD: Double = 0
    /// Preferred region's raw value; empty means no preference.
    public var preferredRegionRaw: String = ""

    public init() {}

    public var interests: [CompetitionCategory: Double] {
        get {
            var parsed: [CompetitionCategory: Double] = [:]
            for pair in interestsRaw.split(separator: ",") {
                let parts = pair.split(separator: ":")
                guard parts.count == 2,
                      let category = CompetitionCategory(rawValue: String(parts[0])),
                      let weight = Double(parts[1]) else { continue }
                parsed[category] = min(1, max(0, weight))
            }
            return parsed
        }
        set {
            // Category declaration order, not dictionary order, so the same
            // weights always serialize to the same string - `fingerprint`
            // depends on that.
            interestsRaw = CompetitionCategory.allCases
                .compactMap { category in
                    newValue[category].map { "\(category.rawValue):\($0)" }
                }
                .joined(separator: ",")
        }
    }

    public var preferredRegion: Region? {
        get { Region(rawValue: preferredRegionRaw) }
        set { preferredRegionRaw = newValue?.rawValue ?? "" }
    }

    /// Every field that can move a score, in one string - the change key the
    /// list observes to re-adopt the snapshot and re-rank without a relaunch.
    public var fingerprint: String {
        [interestsRaw, cfHandle, cfRating.map(String.init) ?? "",
         String(weeklyHours), String(prizeFloorUSD), preferredRegionRaw]
            .joined(separator: "|")
    }

    /// The single row, created on first need. The profile is singular by
    /// design: fetch returns whatever exists, and only emptiness inserts.
    @MainActor
    public static func fetchOrCreate(in context: ModelContext) throws -> UserProfile {
        if let existing = try context.fetch(FetchDescriptor<UserProfile>()).first {
            return existing
        }
        let fresh = UserProfile()
        context.insert(fresh)
        try context.save()
        return fresh
    }
}

/// The profile as a plain Sendable value - what `FitScorer` actually scores
/// against. A snapshot rather than the `@Model` itself so the scorer stays
/// pure and testable, and so a score can never observe a half-edited row.
public struct ProfileSnapshot: Sendable, Equatable {
    /// Absent category reads as the neutral 0.5.
    public var interests: [CompetitionCategory: Double]
    public var cfRating: Int?
    public var weeklyHours: Double
    public var prizeFloorUSD: Double
    public var preferredRegion: Region?
    /// The reader's clock, for the sane-start-hour component. Injected so
    /// tests are timezone-stable; the app passes `TimeZone.current`.
    public var timezone: TimeZone

    public init(interests: [CompetitionCategory: Double] = [:],
                cfRating: Int? = nil,
                weeklyHours: Double = 10,
                prizeFloorUSD: Double = 0,
                preferredRegion: Region? = nil,
                timezone: TimeZone = .current) {
        self.interests = interests
        self.cfRating = cfRating
        self.weeklyHours = weeklyHours
        self.prizeFloorUSD = prizeFloorUSD
        self.preferredRegion = preferredRegion
        self.timezone = timezone
    }

    /// What scoring uses before the person has touched Settings: every
    /// weight neutral, no floor, 10h a week. Computed rather than stored so
    /// the timezone is always the machine's current one.
    public static var defaults: ProfileSnapshot { ProfileSnapshot() }
}

extension UserProfile {
    /// The value form of this row, taken at read time.
    public func snapshot(timezone: TimeZone = .current) -> ProfileSnapshot {
        ProfileSnapshot(interests: interests,
                        cfRating: cfRating,
                        weeklyHours: weeklyHours,
                        prizeFloorUSD: prizeFloorUSD,
                        preferredRegion: preferredRegion,
                        timezone: timezone)
    }
}

extension UserProfile {
    /// Interest weights suggested by the person's own marking history - every
    /// mark is a vote for its categories, and the pipeline is a confidence
    /// scale for free: advancing a competition is a stronger vote than
    /// starring it, and dropping one is a vote against.
    ///
    /// An explicit action, never continuous inference: weights that silently
    /// drifted as marks changed would reshuffle the ranked list without the
    /// person touching anything, which is exactly the instability the COMP-5
    /// epic exists to prevent. Settings runs this when asked and writes the
    /// result into the sliders, where it is visible and correctable.
    ///
    /// Normalized to 0...1 by the strongest positive category; a net-negative
    /// category clamps to 0 (a recorded "not this"). Categories never voted
    /// on are ABSENT so the caller keeps their current weights - and with no
    /// marks at all the suggestion is empty, the cold-start rule.
    public static func suggestedInterests(
        from competitions: [Competition]
    ) -> [CompetitionCategory: Double] {
        var votes: [CompetitionCategory: Double] = [:]
        for competition in competitions {
            guard let status = competition.status else { continue }
            let vote: Double = switch status {
            case .interested: 1
            case .applied: 2
            case .joined, .done: 3
            case .dropped: -1
            }
            for tag in competition.shownCategoryTags {
                votes[tag, default: 0] += vote
            }
        }
        guard let top = votes.values.max(), top > 0 else { return [:] }
        return votes.mapValues { min(1, max(0, $0 / top)) }
    }
}
