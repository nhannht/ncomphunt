import Foundation
import SwiftData

/// Persisted competition. The store is a rebuildable cache of remote feeds;
/// `firstSeen` and `trackedIssueID` are the only fields that carry local state.
@Model
public final class Competition {
    #Unique<Competition>([\.key])

    public var key: String
    public var source: String
    public var title: String
    public var organizer: String
    public var url: String
    public var categoryRaw: String
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

    public var category: CompetitionCategory {
        get { CompetitionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public var region: Region {
        get { Region(rawValue: regionRaw) ?? .global }
        set { regionRaw = newValue.rawValue }
    }

    public init(dto: CompetitionDTO, category: CompetitionCategory, region: Region, now: Date = .now) {
        self.key = dto.key
        self.source = dto.source
        self.title = dto.title
        self.organizer = dto.organizer
        self.url = dto.url
        self.categoryRaw = category.rawValue
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
    }

    /// Refresh from a newer DTO, preserving `firstSeen` and tracking state.
    /// Never-downgrade policy: sources sometimes serve slimmer copies of a
    /// post they served richly before (ybox recommendation rails), so an
    /// empty incoming field must not clobber a known value.
    public func update(from dto: CompetitionDTO, category: CompetitionCategory, region: Region, now: Date = .now) {
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
        if category != .other || self.category == .other {
            self.categoryRaw = category.rawValue
        }
        if region == .vietnam {
            self.regionRaw = region.rawValue
        }
        self.lastSeen = now
    }
}
