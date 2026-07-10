import CompHuntKit
import SwiftData
import SwiftUI

@main
struct CompHuntApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(model)
        }
        .modelContainer(model.container)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
