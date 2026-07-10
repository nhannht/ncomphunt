/// A source plugin. A source that throws is reported and skipped by the
/// refresh engine; it must never kill the run (job-recon contract).
public protocol CompetitionSource: Sendable {
    var name: String { get }
    func fetch() async throws -> [CompetitionDTO]
}
