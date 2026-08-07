#if os(macOS)
import AppKit
#endif
import AppIntents
import CompHuntKit
import CoreSpotlight
import SwiftData
import SwiftUI

/// The whole app, minus the `@main` attribute.
///
/// Split out from `CompHuntApp` so the entry point holds nothing but `@main`
/// and one line of body. Keep it that way: an entry point that accretes logic
/// is the file nobody thinks to look in.
struct CompHuntRoot: Scene {
    // No inline default: the instance is built in `init` so the same one can
    // be registered with AppDependencyManager (an inline default would run
    // first and a second, discarded AppModel would open the store twice).
    @State private var model: AppModel
    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    #if os(macOS)
    static let dashboardWindowID = "dashboard"
    #endif

    init() {
        // App Intents (Siri, Spotlight, Shortcuts) resolve entities through
        // the one AppModel; registering it here is what lets a background
        // intent launch reach the store without a second container.
        let model = AppModel()
        _model = State(initialValue: model)
        AppDependencyManager.shared.add(dependency: model)
        Notifier.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environment(model)
                .countsTowardDockIcon()
                .onOpenURL { url in
                    model.handleDeepLink(url)
                    #if os(macOS)
                    DockVisibility.prepareToShowWindow()
                    #endif
                }
                // Spotlight fallback: a result opened through the classic
                // searchable-item activity (rather than OpenCompetitionIntent)
                // still lands on the right row. The item identifier IS the
                // dedupe key, so it rides the same deep-link route.
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let key = activity.userInfo?[CSSearchableItemActivityIdentifier]
                        as? String else { return }
                    model.handleDeepLink(competitionDeepLink(key: key))
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
        // A Live Activity face flip that fell due while backgrounded is
        // applied on the next look, not the next refresh cycle.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.reconcileActivities() }
        }
        #endif

        #if os(macOS)
        // Its own window, following Settings: the dashboard is about the whole
        // store, not about whatever the main window is filtered to, so it must
        // not live inside that window's layout toggle.
        Window("Dashboard", id: CompHuntRoot.dashboardWindowID) {
            DashboardView()
                .environment(model)
                .frame(minWidth: 420, minHeight: 480)
                .countsTowardDockIcon()
        }
        .modelContainer(model.container)
        .defaultSize(width: 620, height: 720)

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
                .countsTowardDockIcon()
        }
        // The Profile tab reads and writes the UserProfile row via @Query,
        // unlike the other tabs (Keychain/AppStorage), so this scene needs
        // the container the rest of the app already carries.
        .modelContainer(model.container)
        #endif
    }
}
