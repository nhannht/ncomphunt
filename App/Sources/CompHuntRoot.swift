import AppKit
import CompHuntKit
import SwiftData
import SwiftUI

/// The whole app, minus the `@main` attribute.
///
/// Split out from `CompHuntApp` so a build that ships the paid module can
/// substitute its own entry point - registering capabilities into `ProRegistry`
/// before the first scene renders - and still present exactly this. Everything
/// the two builds share lives here; the entry point files hold nothing but
/// `@main` and one line of body. Keep it that way: anything added to an entry
/// point has to be written twice and will drift.
struct CompHuntRoot: Scene {
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
