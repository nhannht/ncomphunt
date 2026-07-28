import Foundation

/// Where the optional paid capabilities register themselves at launch.
///
/// Both slots are nil in this repository's build, and nothing here ever fills
/// them: the free app is exactly the app it was before these slots existed. A
/// build that ships the paid module substitutes its own entry point, which
/// populates these before the first scene renders.
///
/// This is the whole gate. There is no build flag, no `#if`, and no runtime
/// class lookup - a capability is present precisely when something injected it,
/// so the free build cannot accidentally half-enable one, and the UI has a
/// single question to ask.
///
/// When purchasing arrives, the entitlement check decides whether to inject.
/// Nothing below this line changes.
@MainActor
public enum ProRegistry {
    /// Natural-language querying. nil means the app shows its ordinary filter
    /// controls and no query field affordance.
    public static var queryGenerator: (any QueryGenerating)?

    /// Worth-it scoring. nil means the list sorts and renders as it always has,
    /// with no score badge and no best-fit order.
    public static var ranking: (any RankingProvider)?
}
