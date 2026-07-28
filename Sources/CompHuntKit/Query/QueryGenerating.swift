import Foundation

/// Turns a person's sentence into a `CompetitionQuery`.
///
/// Declared here, never implemented here. The only implementation is on-device
/// and lives outside this package; this repository holds the contract so the
/// app can render a generated query without knowing what produced it.
public protocol QueryGenerating: Sendable {
    /// `now` is injected rather than read inside, so relative phrasing like
    /// "this month" resolves deterministically and the mapping stays testable.
    func generate(from text: String, now: Date) async throws -> CompetitionQuery

    /// nil when generation is usable right now. Otherwise a sentence fit to
    /// show a person, explaining why it is not.
    ///
    /// Asked through the protocol rather than checked in the view, so the app
    /// can degrade honestly without importing the framework that answers it -
    /// and so a future generator with different prerequisites needs no UI
    /// change. It is re-read on each appearance because the answer changes
    /// while the app is running: a person can switch Apple Intelligence off,
    /// or a model can still be downloading.
    var unavailableReason: String? { get }
}
