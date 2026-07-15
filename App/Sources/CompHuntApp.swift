import AppKit
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
                .onOpenURL { url in
                    model.handleDeepLink(url)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(model.container)

        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .modelContainer(model.container)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
