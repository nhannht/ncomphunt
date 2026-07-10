import Foundation

/// One normalized competition from any source, before persistence.
/// Sources return plain values; SwiftData writes happen in the engine layer.
public struct CompetitionDTO: Sendable, Equatable {
    public var source: String
    public var title: String
    public var organizer: String
    public var url: String
    /// Set by the source when unambiguous (CTFtime -> .ctf); nil lets the classifier decide.
    public var category: CompetitionCategory?
    public var location: String
    public var prize: String
    public var details: String
    public var startDate: Date?
    public var endDate: Date?
    public var registrationDeadline: Date?
    /// Classifier input: themes, resource names, format hints.
    public var tags: [String]

    public init(
        source: String,
        title: String,
        organizer: String = "",
        url: String,
        category: CompetitionCategory? = nil,
        location: String = "",
        prize: String = "",
        details: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        registrationDeadline: Date? = nil,
        tags: [String] = []
    ) {
        self.source = source
        self.title = title
        self.organizer = organizer
        self.url = url
        self.category = category
        self.location = location
        self.prize = prize
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.registrationDeadline = registrationDeadline
        self.tags = tags
    }

    /// Dedupe key: normalized URL without query noise (job-recon `Job.key()` pattern).
    public var key: String {
        var normalized = url.split(separator: "?", maxSplits: 1).first.map(String.init) ?? url
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        normalized = normalized.lowercased()
        return normalized.isEmpty
            ? "\(source):\(organizer):\(title)".lowercased()
            : normalized
    }
}
