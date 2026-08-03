import CompHuntKit
import SwiftUI

/// The menu-bar item's label: a live countdown to the next upcoming contest,
/// e.g. "CTF 2h14m". Falls back to the trophy icon alone when nothing is
/// upcoming. Reads the @Observable snapshot on AppModel, refreshed every minute.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        if let status = model.menuBarStatus {
            let text = status.code.isEmpty
                ? status.countdown
                : "\(status.code) \(status.countdown)"
            // The minute tick rolls its digits instead of snapping. If the
            // MenuBarExtra bridge ever flattens this to a plain swap it is a
            // harmless no-op, not a bug.
            Label(text, systemImage: "trophy")
                .contentTransition(.numericText())
                .animation(Motion.state, value: text)
        } else {
            Image(systemName: "trophy")
        }
    }
}
