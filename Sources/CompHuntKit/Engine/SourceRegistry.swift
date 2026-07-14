import Foundation

/// Every source the app knows, in refresh priority order: on duplicate URLs
/// within one batch the earliest source's fields win (see CompetitionStore),
/// so richer feeds come first and search leads last.
public enum SourceID: String, CaseIterable, Sendable, Identifiable {
    case ctftime
    case devpost
    case clist
    case codeforces
    case mlcontests
    case ybox
    case contestwatchers
    case brave
    case googlesearch

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ctftime: "CTFtime"
        case .devpost: "Devpost"
        case .clist: "clist.by"
        case .codeforces: "Codeforces"
        case .mlcontests: "ML Contests"
        case .ybox: "ybox.vn"
        case .contestwatchers: "Contest Watchers"
        case .brave: "Brave Search"
        case .googlesearch: "Google Search"
        }
    }

    /// What the user must configure before the source can run; nil = keyless.
    public var configHint: String? {
        switch self {
        case .clist: "CLIST_USERNAME + CLIST_API_KEY in ~/.claude/secrets.yml"
        case .brave: "BRAVE_API_KEY in ~/.claude/secrets.yml"
        case .googlesearch: "GOOGLE_CSE_KEY + GOOGLE_CSE_CX in ~/.claude/secrets.yml"
        default: nil
        }
    }

    /// Whether the required keys are present on this machine (always true
    /// for keyless sources).
    public var isConfigured: Bool {
        switch self {
        case .clist: SecretsReader.clistCredentials() != nil
        case .brave: SecretsReader.braveKey() != nil
        case .googlesearch: SecretsReader.googleCSE() != nil
        default: true
        }
    }

    /// Search-engine lead sources spend metered API quota, so the app
    /// includes them at most once per day rather than on every refresh.
    public var isSearch: Bool {
        switch self {
        case .brave, .googlesearch: true
        default: false
        }
    }

    public func makeSource() -> any CompetitionSource {
        switch self {
        case .ctftime: CTFtimeSource()
        case .devpost: DevpostSource()
        case .clist: ClistSource()
        case .codeforces: CodeforcesSource()
        case .mlcontests: MLContestsSource()
        case .ybox: YboxSource()
        case .contestwatchers: ContestWatchersSource()
        case .brave: BraveSearchSource()
        case .googlesearch: GoogleSearchSource()
        }
    }
}
