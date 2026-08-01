#if os(macOS)
import AppKit
#endif
import CompHuntKit
import SwiftData
import SwiftUI

/// The whole app, minus the `@main` attribute.
///
/// Split out from `CompHuntApp` so the entry point holds nothing but `@main`
/// and one line of body. Keep it that way: an entry point that accretes logic
/// is the file nobody thinks to look in.
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
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                }
                #if os(iOS)
                // Background refresh stands in for the always-running macOS
                // auto-refresh timer.
                .backgroundRefreshScheduling()
                #endif
        }
        .modelContainer(model.container)
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.perform(model: model)
        }
        #endif

        #if os(macOS)
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
        #endif
    }
}
