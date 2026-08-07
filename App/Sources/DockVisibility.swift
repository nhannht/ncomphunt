#if os(macOS)
import AppKit
#endif
import SwiftUI

#if os(macOS)
/// Keeps the Dock icon in step with what the user is doing: any real window
/// (main, Dashboard, Settings) visible means a regular app; none means the
/// app slips to accessory - menu-bar extra only, no Dock icon, no Cmd-Tab
/// entry - so the always-running background half never sits in the Dock.
/// Derived from window state, never a setting.
@MainActor
enum DockVisibility {
    private static var visibleWindows = 0

    static func windowAppeared() {
        visibleWindows += 1
        apply()
    }

    static func windowDisappeared() {
        visibleWindows = max(0, visibleWindows - 1)
        apply()
    }

    /// Restore the Dock icon and activate BEFORE summoning a window (menu
    /// bar item, deep link): a window opened by an accessory app lands
    /// behind the frontmost app otherwise.
    static func prepareToShowWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func apply() {
        let policy: NSApplication.ActivationPolicy =
            visibleWindows > 0 ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
#endif

/// Feeds a window's lifetime into the Dock-icon policy. Attach to the CONTENT
/// of every real window scene (main, Dashboard, Settings) and nowhere else -
/// MenuBarExtra content appears every time the menu opens, which is exactly
/// the surface that must not count. No-op on iOS, where there is no Dock.
struct DockWindowCounting: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onAppear { DockVisibility.windowAppeared() }
            .onDisappear { DockVisibility.windowDisappeared() }
        #else
        content
        #endif
    }
}

extension View {
    func countsTowardDockIcon() -> some View {
        modifier(DockWindowCounting())
    }
}
