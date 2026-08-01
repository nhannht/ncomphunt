import Foundation

/// Turns a person's sentence into a `SearchQuery`.
///
/// The contract the app renders against, separate from `NLFilterGenerator` (the
/// on-device implementation) so the mapping stays testable and the UI never has
/// to know what produced a generated query.
public protocol QueryGenerating: Sendable {
    /// `now` is injected rather than read inside, so relative phrasing like
    /// "this month" resolves deterministically and the mapping stays testable.
    func generate(from text: String, now: Date) async throws -> SearchQuery

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
