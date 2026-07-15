import SwiftUI
import WidgetKit

/// Entry point for the widget extension. WidgetKit discovers the widgets from
/// this bundle; the extension's data comes from the App Group snapshot the main
/// app writes (see CompHuntKit `WidgetSnapshot`).
@main
struct CompHuntWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingContestsWidget()
    }
}
