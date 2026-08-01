import Foundation

/// The App Group shared between the main app and the widget extension. The app
/// writes the next-contests snapshot into this container; the widget reads it.
/// On macOS 15+ the group container is protected, so both processes need the
/// `com.apple.security.application-groups` entitlement carrying this id to reach
/// it. If `containerURL` resolves nil at runtime the group id and the entitlement
/// disagree (try the team-prefixed `V3P5U9Z68M.group...` form instead).
public enum AppGroup {
    /// Must match the platform's `.entitlements` files on both the app and the
    /// widget target.
    /// - macOS: team-id-prefixed form, the macOS-native App Group convention
    ///   that signs without a provisioning profile (the bare iOS-style `group.`
    ///   id would demand one).
    /// - iOS: bare `group.` form, the only shape iOS provisioning accepts; iOS
    ///   always provisions anyway, so the macOS constraint never applies.
    #if os(iOS)
    public static let id = "group.com.nhannht.ncomphunt"
    #else
    public static let id = "V3P5U9Z68M.group.com.nhannht.ncomphunt"
    #endif

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// The next-contests snapshot file inside the group container.
    public static var snapshotURL: URL? {
        containerURL?.appending(path: "next-contests.json")
    }
}

/// `ncomphunt://open?key=<key>` - the one route into a specific competition,
/// used by both a widget row tap and a reminder tap.
///
/// Built through `URLComponents` rather than interpolation because a dedupe key
/// IS a URL: interpolating one straight into a query string loses everything
/// after its `?` and mangles its slashes.
public func competitionDeepLink(key: String) -> URL {
    var components = URLComponents()
    components.scheme = "ncomphunt"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "key", value: key)]
    return components.url ?? URL(string: "ncomphunt://open")!
}
