import Foundation

/// Where a competition sits in the user's own pipeline.
///
/// This is the only user-authored state in the app, and everything personal
/// hangs off it. A competition with a status is MARKED; marking is what earns
/// it a deadline reminder. Nothing unmarked ever notifies, which is the whole
/// notification model in one sentence.
///
/// ```
///  (unmarked) -> interested -> applied -> joined -> done
///                     |           |          |
///                     +-----------+----------+-> dropped
/// ```
///
/// The order of `allCases` is the pipeline order, and the dashboard funnel and
/// every picker read it, so a new state is added in its right place rather than
/// appended.
public enum CompetitionStatus: String, Codable, CaseIterable, Sendable {
    /// Worth a look. What the star sets, and where nearly everything starts.
    case interested
    case applied
    case joined
    /// Finished, whatever the result. Deliberately not split into won/lost:
    /// the app cannot verify an outcome, and a field only the person can fill
    /// truthfully is a field most people leave wrong.
    case done
    /// Looked at and decided against. Distinct from unmarked, because it
    /// records a decision - without it the same competition reads as new every
    /// time it comes round.
    case dropped

    public var displayName: String {
        switch self {
        case .interested: "Interested"
        case .applied: "Applied"
        case .joined: "Joined"
        case .done: "Done"
        case .dropped: "Dropped"
        }
    }

    public var systemImage: String {
        switch self {
        case .interested: "star.fill"
        case .applied: "paperplane.fill"
        case .joined: "checkmark.seal.fill"
        case .done: "flag.checkered"
        case .dropped: "xmark.circle"
        }
    }

    /// Whether this state still has a deadline worth being reminded about.
    ///
    /// A finished or abandoned competition keeps its mark - the record is the
    /// point - but must stop notifying, or the pipeline turns into a source of
    /// noise exactly as it fills up.
    public var wantsReminders: Bool {
        switch self {
        case .interested, .applied, .joined: true
        case .done, .dropped: false
        }
    }

    /// Spellings a person might type after `status:`.
    var searchAliases: [String] {
        switch self {
        case .interested: [rawValue, "starred", "saved", "bookmarked", "star"]
        case .applied: [rawValue, "apply", "submitted", "registered"]
        case .joined: [rawValue, "join", "participating", "in"]
        case .done: [rawValue, "finished", "complete", "completed", "over"]
        case .dropped: [rawValue, "drop", "skipped", "passed", "rejected"]
        }
    }
}

public extension Competition {
    /// The stored `statusRaw`, as its enum. nil means never marked.
    ///
    /// An unrecognised raw value also reads as nil rather than trapping: a
    /// store written by a LATER version with a state this build has never heard
    /// of has to degrade to "unmarked here", not crash.
    var status: CompetitionStatus? {
        get { statusRaw.flatMap(CompetitionStatus.init(rawValue:)) }
        set { statusRaw = newValue?.rawValue }
    }

    var isMarked: Bool { status != nil }

    /// Marked AND still in a state that wants telling about deadlines.
    var wantsReminders: Bool { status?.wantsReminders ?? false }
}
