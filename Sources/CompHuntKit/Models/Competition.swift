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

    /// Refresh mutable fields from a newer DTO, preserving `firstSeen` and tracking state.
    public func update(from dto: CompetitionDTO, category: CompetitionCategory, region: Region, now: Date = .now) {
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
        self.lastSeen = now
    }
}
