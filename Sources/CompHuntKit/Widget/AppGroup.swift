import Foundation

/// The App Group shared between the main app and the widget extension. The app
/// writes the next-contests snapshot into this container; the widget reads it.
/// On macOS 15+ the group container is protected, so both processes need the
/// `com.apple.security.application-groups` entitlement carrying this id to reach
/// it. If `containerURL` resolves nil at runtime the group id and the entitlement
/// disagree (try the team-prefixed `V3P5U9Z68M.group...` form instead).
public enum AppGroup {
    /// Team-id-prefixed form: the macOS-native App Group convention that signs
    /// without a provisioning profile (the bare iOS-style `group.` id would
    /// demand one). Must match both `.entitlements` files.
    public static let id = "V3P5U9Z68M.group.com.nhannht.ncomphunt"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// The next-contests snapshot file inside the group container.
    public static var snapshotURL: URL? {
        containerURL?.appending(path: "next-contests.json")
    }
}
