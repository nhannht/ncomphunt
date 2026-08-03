import Foundation
import SwiftData

/// Persisted competition. The store is a rebuildable cache of remote feeds;
/// `firstSeen`, `trackedIssueID` and `statusRaw` are the only fields that carry
/// local state.
///
/// Changing the stored properties here REQUIRES a new version in
/// `CompetitionSchema.swift`. The store shipped, and an unversioned change traps
/// at launch rather than degrading.
@Model
public final class Competition {
    #Unique<Competition>([\.key])

    public var key: String
    public var source: String
    public var title: String
    public var organizer: String
    public var url: String
    public var categoryRaw: String
    /// Every category the classifier found, comma-joined in priority order -
    /// a competition can genuinely be several things at once, and this is
    /// where the answers beyond the first stop being thrown away.
    /// `categoryRaw` is always the FIRST entry (or `other` when empty): a
    /// projection, never a second decision, so the two can never disagree.
    /// Empty means "never computed" - rows from before schema V3, backfilled
    /// on the next refresh. Added in V3; see `CompetitionSchema.swift`.
    public var categoryTagsRaw: String = ""
    public var regionRaw: String
    public var location: String
    public var prize: String
    public var details: String
    public var startDate: Date?
    public var endDate: Date?
    public var registrationDeadline: Date?
    public var firstSeen: Date
    public var lastSeen: Date
    /// YouTrack issue id (e.g. COMP-12) once the user tracks this competition.
    public var trackedIssueID: String?
    /// The user's pipeline state, or nil when they have not marked this at all.
    /// Added in schema V2; see `CompetitionSchema.swift`.
    public var statusRaw: String?

    public var category: CompetitionCategory {
        get { CompetitionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// The persisted tag set, decoded. Setting also writes `categoryRaw`, so
    /// the projection invariant cannot be broken from outside.
    public var categoryTags: [CompetitionCategory] {
        get {
            categoryTagsRaw.split(separator: ",")
                .compactMap { CompetitionCategory(rawValue: String($0)) }
        }
        set {
            categoryTagsRaw = newValue.map(\.rawValue).joined(separator: ",")
            categoryRaw = (newValue.first ?? .other).rawValue
        }
    }

    /// Whether this row belongs under `category` when filtering - containment
    /// over the tag set, not equality on the projection. Falls back to the
    /// single stored category for rows whose tags were never computed, and
    /// that same fallback is what lets an unplaced row answer to `.other`
    /// (the empty tag set holds nothing, honestly).
    public func belongs(to category: CompetitionCategory) -> Bool {
        self.category == category || categoryTags.contains(category)
    }

    /// The tag set for surfaces that render them all, never empty: the
    /// computed tags, or the single stored category for rows whose tags were
    /// never computed - the same fallback `belongs(to:)` filters by, so what
    /// a row shows and where it appears cannot disagree.
    public var shownCategoryTags: [CompetitionCategory] {
        let tags = categoryTags
        return tags.isEmpty ? [category] : tags
    }

    public var region: Region {
        get { Region(rawValue: regionRaw) ?? .global }
        set { regionRaw = newValue.rawValue }
    }

    /// Takes the classifier's full tag list rather than a single category:
    /// `categoryRaw` is derived from it here, which is what makes the
    /// projection an invariant instead of a convention callers must remember.
    public init(dto: CompetitionDTO, tags: [CompetitionCategory], region: Region, now: Date = .now) {
        self.key = dto.key
        self.source = dto.source
        self.title = dto.title
        self.organizer = dto.organizer
        self.url = dto.url
        self.categoryRaw = (tags.first ?? .other).rawValue
        self.categoryTagsRaw = tags.map(\.rawValue).joined(separator: ",")
        self.regionRaw = region.rawValue
        self.location = dto.location
        self.prize = dto.prize
        self.details = dto.details
        self.startDate = dto.startDate
        self.endDate = dto.endDate
        self.registrationDeadline = dto.registrationDeadline
        self.firstSeen = now
        self.lastSeen = now
        self.trackedIssueID = nil
        self.statusRaw = nil
    }

    /// Refresh from a newer DTO, preserving `firstSeen` and every local field.
    /// `trackedIssueID` and `statusRaw` are simply never assigned here, which is
    /// what keeps a refresh from erasing what the user recorded.
    /// Never-downgrade policy: sources sometimes serve slimmer copies of a
    /// post they served richly before (ybox recommendation rails), so an
    /// empty incoming field must not clobber a known value.
    public func update(from dto: CompetitionDTO, tags: [CompetitionCategory], region: Region, now: Date = .now) {
        if !dto.title.isEmpty { self.title = dto.title }
        if !dto.organizer.isEmpty { self.organizer = dto.organizer }
        if !dto.url.isEmpty { self.url = dto.url }
        if !dto.location.isEmpty { self.location = dto.location }
        if !dto.prize.isEmpty { self.prize = dto.prize }
        if !dto.details.isEmpty { self.details = dto.details }
        if let start = dto.startDate { self.startDate = start }
        if let end = dto.endDate { self.endDate = end }
        if let deadline = dto.registrationDeadline { self.registrationDeadline = deadline }
        // Reclassification may add signal but never dumps a row back into the
        // default buckets a poorer copy would produce.
        if !tags.isEmpty || self.category == .other {
            self.categoryTags = tags
        }
        if region == .vietnam {
            self.regionRaw = region.rawValue
        }
        self.lastSeen = now
    }
}
