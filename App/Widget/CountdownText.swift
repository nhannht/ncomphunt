// The Widget directory compiles into BOTH widget targets (project.yml); every
// consumer of this view (Live Activity, accessory families) is iOS-only, so
// the whole file is fenced to keep the macOS extension lean.
#if os(iOS)
import SwiftUI

/// The ticking countdown shared by the Live Activity and the accessory
/// families. `Text(timerInterval:)` renders "H:MM:SS", which for a contest
/// days away reads as a wall of digits - so far-out targets show the system's
/// relative phrase ("in 3 days") instead. The branch is fixed at render time,
/// and every reconcile or timeline reload re-renders, so a countdown crossing
/// the day boundary flips on the next refresh or foreground.
struct CountdownText: View {
    let target: Date
    var alignment: TextAlignment = .trailing

    /// The bare `Text`, exposed because accessoryInline renders exactly one
    /// line of text and needs to concatenate the countdown into it.
    var text: Text {
        if target.timeIntervalSinceNow > 24 * 3600 {
            Text(target, style: .relative)
        } else {
            Text(timerInterval: min(.now, target)...target, countsDown: true)
                .monospacedDigit()
        }
    }

    var body: some View {
        text.multilineTextAlignment(alignment)
    }
}
#endif
