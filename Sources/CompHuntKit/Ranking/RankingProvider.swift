import Foundation

/// A competition with a worth-it score attached.
///
/// `reasons` exists because an unexplained number is not actionable: the score
/// has to be able to say why it landed where it did.
public struct RankedCompetition: Sendable {
    /// 0-100. Comparable only against other scores from the same provider.
    public let score: Int
    /// One line summarising the verdict.
    public let headline: String
    /// The factors behind the score, strongest first.
    public let reasons: [String]

    public init(score: Int, headline: String, reasons: [String]) {
        self.score = score
        self.headline = headline
        self.reasons = reasons
    }
}

/// Scores competitions against whatever profile the implementation holds.
///
/// Contract, and the reason scoring is not merely another `SearchQuery`
/// axis: the score must be STABLE across refreshes. A ranked list that
/// reshuffles because the same inputs scored differently is worse than no
/// ranking. That is why no model output may reach a score, while it may drive a
/// query - a query is transient and the person sees it immediately.
///
/// Declared here, never implemented here.
public protocol RankingProvider: Sendable {
    func rank(_ competitions: [Competition]) -> [RankedCompetition]
}
