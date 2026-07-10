/// Competition taxonomy shared by sources, classifier, store, and UI.

public enum CompetitionCategory: String, Codable, CaseIterable, Sendable {
    case cp
    case ctf
    case ai
    case hackathon
    case design
    case other

    public var displayName: String {
        switch self {
        case .cp: "Competitive Programming"
        case .ctf: "CTF"
        case .ai: "AI"
        case .hackathon: "Hackathon"
        case .design: "Design"
        case .other: "Other"
        }
    }
}

public enum Region: String, Codable, CaseIterable, Sendable {
    case vietnam
    case global

    public var displayName: String {
        switch self {
        case .vietnam: "Vietnam"
        case .global: "Global"
        }
    }
}
