#if os(iOS)
import BackgroundTasks
import SwiftUI

/// iOS stand-in for the always-running macOS auto-refresh timer: the system
/// wakes the app for a BGAppRefreshTask instead. The task id must stay in
/// sync with `BGTaskSchedulerPermittedIdentifiers` in CompHunt-iOS-Info.plist;
/// the `.backgroundTask(.appRefresh(_:))` scene modifier in CompHuntRoot
/// registers the handler and cancels it on expiration.
enum BackgroundRefresh {
    static let taskID = "com.nhannht.ncomphunt.refresh"

    /// Ask for the next wake one auto-refresh interval out. The system treats
    /// it as an earliest date, not a promise; submit failures (e.g. on the
    /// simulator, which never fires these) are not actionable.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// One background wake: chain the next request first, so an expired or
    /// failed run cannot break the chain, then refresh.
    static func perform(model: AppModel) async {
        schedule()
        await model.refresh()
    }
}

extension View {
    /// Attach inside the window group: re-arms the background refresh request
    /// whenever the app leaves the foreground.
    func backgroundRefreshScheduling() -> some View {
        modifier(BackgroundRefreshModifier())
    }
}

private struct BackgroundRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
    }
}
#endif
