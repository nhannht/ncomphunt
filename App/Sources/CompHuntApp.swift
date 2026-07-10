import CompHuntKit
import SwiftData
import SwiftUI

@main
struct CompHuntApp: App {
    @State private var model = AppModel()

    init() {
        Notifier.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environment(model)
        }
        .modelContainer(model.container)

        MenuBarExtra("CompHunt", systemImage: "trophy") {
            MenuBarView()
                .environment(model)
        }
        .modelContainer(model.container)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
