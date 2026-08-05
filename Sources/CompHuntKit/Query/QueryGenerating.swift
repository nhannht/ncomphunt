import Foundation

/// Whether sentences can be turned into filters right now, and if not, what a
/// person can do about it.
///
/// A bare reason string could say WHY, but not whether the app should draw an
/// open-settings affordance next to it - `deviceNotEligible` is unfixable,
/// `modelNotReady` passes on its own, and only a switched-off feature is one
/// settings visit away. Same shape as the app's notification
/// `PermissionStatus`, for the same reason: an OS-gated capability must never
/// fail silent (COMP-50).
public enum GeneratorAvailability: Equatable, Sendable {
    case available
    /// `reason` is a sentence fit to show a person. `fixableInSettings` is
    /// whether a system-settings visit can change the answer - the app layer
    /// decides what affordance that earns per platform.
    case unavailable(reason: String, fixableInSettings: Bool)
}

/// Turns a person's sentence into a `SearchQuery`.
///
/// The contract the app renders against, separate from `NLFilterGenerator` (the
/// on-device implementation) so the mapping stays testable and the UI never has
/// to know what produced a generated query.
public protocol QueryGenerating: Sendable {
    /// `now` is injected rather than read inside, so relative phrasing like
    /// "this month" resolves deterministically and the mapping stays testable.
    func generate(from text: String, now: Date) async throws -> SearchQuery

    /// Asked through the protocol rather than checked in the view, so the app
    /// can degrade honestly without importing the framework that answers it -
    /// and so a future generator with different prerequisites needs no UI
    /// change. It is re-read on each appearance because the answer changes
    /// while the app is running: a person can switch Apple Intelligence off,
    /// or a model can still be downloading.
    var availability: GeneratorAvailability { get }
}
