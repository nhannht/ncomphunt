import Foundation
import Yams

public struct ClistCredentials: Sendable {
    public let username: String
    public let apiKey: String

    public init(username: String, apiKey: String) {
        self.username = username
        self.apiKey = apiKey
    }
}

public struct GoogleCSEConfig: Sendable {
    public let apiKey: String
    /// Programmable Search Engine id (the `cx` parameter).
    public let engineID: String

    public init(apiKey: String, engineID: String) {
        self.apiKey = apiKey
        self.engineID = engineID
    }
}

public struct YouTrackConfig: Sendable {
    /// Instance base URL without the MCP suffix, e.g. https://youtrack.example.com
    public let baseURL: String
    public let token: String

    public init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }
}

/// Reads local machine config. Nothing here is ever hardcoded or committed.
/// Each logical config resolves Keychain-first (a `CredentialStoring`, the
/// sandbox-safe source) and falls back to legacy dev files: clist/Brave/Google
/// keys in ~/.claude/secrets.yml (flat UPPER_SNAKE_CASE keys, the repo-wide
/// schema), the YouTrack URL and bearer token in ~/.claude.json under
/// mcpServers.youtrack (same discovery as job-recon's config.py). The
/// placeholder/empty filter applies to values from both origins.
public enum SecretsReader {
    public static var defaultSecretsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude/secrets.yml")
    }

    public static var defaultClaudeJSONPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude.json")
    }

    public static func clistCredentials(
        secretsPath: URL = defaultSecretsPath,
        store: CredentialStoring = KeychainCredentialStore.shared
    ) -> ClistCredentials? {
        if let username = nonPlaceholder(store.get(.CLIST_USERNAME)),
           let apiKey = nonPlaceholder(store.get(.CLIST_API_KEY)) {
            return ClistCredentials(username: username, apiKey: apiKey)
        }
        guard
            let root = loadSecrets(secretsPath),
            let username = nonPlaceholder(root["CLIST_USERNAME"]),
            let apiKey = nonPlaceholder(root["CLIST_API_KEY"])
        else {
            return nil
        }
        return ClistCredentials(username: username, apiKey: apiKey)
    }

    public static func braveKey(
        secretsPath: URL = defaultSecretsPath,
        store: CredentialStoring = KeychainCredentialStore.shared
    ) -> String? {
        if let key = nonPlaceholder(store.get(.BRAVE_API_KEY)) {
            return key
        }
        guard let root = loadSecrets(secretsPath) else { return nil }
        return nonPlaceholder(root["BRAVE_API_KEY"])
    }

    public static func googleCSE(
        secretsPath: URL = defaultSecretsPath,
        store: CredentialStoring = KeychainCredentialStore.shared
    ) -> GoogleCSEConfig? {
        if let apiKey = nonPlaceholder(store.get(.GOOGLE_CSE_KEY)),
           let engineID = nonPlaceholder(store.get(.GOOGLE_CSE_CX)) {
            return GoogleCSEConfig(apiKey: apiKey, engineID: engineID)
        }
        guard
            let root = loadSecrets(secretsPath),
            let apiKey = nonPlaceholder(root["GOOGLE_CSE_KEY"]),
            let engineID = nonPlaceholder(root["GOOGLE_CSE_CX"])
        else {
            return nil
        }
        return GoogleCSEConfig(apiKey: apiKey, engineID: engineID)
    }

    public static func youTrackConfig(
        claudeJSONPath: URL = defaultClaudeJSONPath,
        store: CredentialStoring = KeychainCredentialStore.shared
    ) -> YouTrackConfig? {
        if let base = nonPlaceholder(store.get(.YOUTRACK_BASE_URL)),
           let rawToken = nonPlaceholder(store.get(.YOUTRACK_TOKEN)) {
            var url = base
            while url.hasSuffix("/") {
                url.removeLast()
            }
            let token = rawToken
                .replacingOccurrences(of: "Bearer ", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !url.isEmpty, !token.isEmpty {
                return YouTrackConfig(baseURL: url, token: token)
            }
        }
        guard
            let data = try? Data(contentsOf: claudeJSONPath),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let servers = root["mcpServers"] as? [String: Any],
            let youtrack = servers["youtrack"] as? [String: Any],
            let mcpURL = youtrack["url"] as? String,
            let headers = youtrack["headers"] as? [String: String],
            let authorization = headers["Authorization"]
        else {
            return nil
        }
        var base = mcpURL
        if base.hasSuffix("/mcp") {
            base = String(base.dropLast("/mcp".count))
        }
        while base.hasSuffix("/") {
            base.removeLast()
        }
        let token = authorization
            .replacingOccurrences(of: "Bearer ", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty, !token.isEmpty else { return nil }
        return YouTrackConfig(baseURL: base, token: token)
    }

    private static func loadSecrets(_ path: URL) -> [String: Any]? {
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return nil }
        return (try? Yams.load(yaml: text)) as? [String: Any]
    }

    /// Filters out empty values and untouched secrets.example.yml placeholders.
    private static func nonPlaceholder(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty,
              !string.hasPrefix("your-") else { return nil }
        return string
    }
}
