import SwiftUI

/// The one place animation curves live - CategoryStyle's idiom applied to
/// motion. Every animated surface reads these three names; a curve that
/// exists once cannot drift into five slightly different springs.
///
/// Rules:
/// - Never write a literal spring or duration in a view. Pick the tier here;
///   if none fits, the vocabulary grows HERE, not at the use site.
/// - A transition that MOVES content pairs with an
///   `accessibilityReduceMotion` check at the use site and falls back to
///   `.opacity`. Digit rolls and color fades are fine under Reduce Motion;
///   sliding and scaling are not.
enum Motion {
    /// State flips: selection, toggles, text swaps, digit rolls.
    static let state = Animation.snappy(duration: 0.25)
    /// Size and order changes: row expansion, list re-ordering, bar growth.
    static let layout = Animation.smooth(duration: 0.35)
    /// Celebratory accents: the rare moment worth a little bounce.
    static let emphasis = Animation.bouncy(duration: 0.4)

    /// The standard reveal for conditional content: blur in, or a plain
    /// cross-fade when the person asked for Reduce Motion. Call with the
    /// view's `accessibilityReduceMotion` environment value.
    static func reveal(reduced: Bool) -> AnyTransition {
        reduced ? .opacity : AnyTransition(.blurReplace)
    }
}
