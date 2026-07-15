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
            Label(text, systemImage: "trophy")
        } else {
            Image(systemName: "trophy")
        }
    }
}
