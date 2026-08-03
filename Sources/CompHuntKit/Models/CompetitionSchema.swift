import Foundation
import SwiftData

/// Versioned history of the persisted schema, and the plan that walks a store
/// from an older shape to the current one.
///
/// This exists because the store SHIPPED. v0.1.0, v0.2.0 and v0.3.0 all wrote
/// the same `Competition` shape, and adding a property to it without a
/// migration plan does not degrade gracefully - it traps:
///
/// ```
/// SwiftData/ModelSnapshot.swift:144: Fatal error:
/// Attempting to set value for unknown key: \Competition.statusRaw
/// ```
///
/// So every future change to `Competition`'s stored properties adds a version
/// here and a stage below. Skipping that step breaks the app on update for
/// everyone who already installed it, and it breaks at launch, before there is
/// any UI to report it in.
///
/// Every version except the NEWEST nests its own frozen copy of the model - a
/// historical record of what shipped that must never be edited, because the
/// migration matches a store against it. Only the newest version points at the
/// live top-level type. When the next version lands, the one it supersedes
/// gets its copy frozen in the same turn: a shipped store sits at that
/// version, and a version aliased to a live type that has since grown a
/// property no longer describes any store that exists.
public enum CompetitionSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Competition.self] }

    /// The shape as shipped through v0.3.0. Frozen: do not add to it.
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
        public var trackedIssueID: String?

        public init(key: String, source: String, title: String) {
            self.key = key
            self.source = source
            self.title = title
            self.organizer = ""
            self.url = ""
            self.categoryRaw = ""
            self.regionRaw = ""
            self.location = ""
            self.prize = ""
            self.details = ""
            self.firstSeen = .now
            self.lastSeen = .now
        }
    }
}

/// Adds `statusRaw`: the competition's place in the user's pipeline.
public enum CompetitionSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Competition.self] }

    /// The shape as shipped through v1.0.x. Frozen: do not add to it.
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
        public var trackedIssueID: String?
        public var statusRaw: String?

        public init(key: String, source: String, title: String) {
            self.key = key
            self.source = source
            self.title = title
            self.organizer = ""
            self.url = ""
            self.categoryRaw = ""
            self.regionRaw = ""
            self.location = ""
            self.prize = ""
            self.details = ""
            self.firstSeen = .now
            self.lastSeen = .now
        }
    }
}

/// Adds `categoryTagsRaw`: every category the classifier found, not only the
/// first. Migrated rows read as empty, which the refresh backfills - see
/// `CompetitionStore.backfillMissingTags`.
public enum CompetitionSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Competition.self] }
}

/// Each step is lightweight: an added property with a default, nothing to
/// transform. V1 -> V2 is verified against a store written by the
/// un-versioned shipped shape - the rows survive and the new column is
/// writable; V2 -> V3 rides the same test through both stages.
public enum CompetitionMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [CompetitionSchemaV1.self, CompetitionSchemaV2.self, CompetitionSchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: CompetitionSchemaV1.self,
                      toVersion: CompetitionSchemaV2.self),
         .lightweight(fromVersion: CompetitionSchemaV2.self,
                      toVersion: CompetitionSchemaV3.self)]
    }
}
