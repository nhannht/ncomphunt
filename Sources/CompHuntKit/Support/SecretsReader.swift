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

/// Reads local machine config. Nothing here is ever hardcoded or committed:
/// clist credentials live in ~/.claude/secrets.yml (flat UPPER_SNAKE_CASE keys,
/// the repo-wide schema), the YouTrack URL and bearer token in ~/.claude.json
/// under mcpServers.youtrack (same discovery as job-recon's config.py).
public enum SecretsReader {
    public static var defaultSecretsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude/secrets.yml")
    }

    public static var defaultClaudeJSONPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude.json")
    }

    public static func clistCredentials(secretsPath: URL = defaultSecretsPath) -> ClistCredentials? {
        guard
            let root = loadSecrets(secretsPath),
            let username = nonPlaceholder(root["CLIST_USERNAME"]),
            let apiKey = nonPlaceholder(root["CLIST_API_KEY"])
        else {
            return nil
        }
        return ClistCredentials(username: username, apiKey: apiKey)
    }

    public static func braveKey(secretsPath: URL = defaultSecretsPath) -> String? {
        guard let root = loadSecrets(secretsPath) else { return nil }
        return nonPlaceholder(root["BRAVE_API_KEY"])
    }

    public static func googleCSE(secretsPath: URL = defaultSecretsPath) -> GoogleCSEConfig? {
        guard
            let root = loadSecrets(secretsPath),
            let apiKey = nonPlaceholder(root["GOOGLE_CSE_KEY"]),
            let engineID = nonPlaceholder(root["GOOGLE_CSE_CX"])
        else {
            return nil
        }
        return GoogleCSEConfig(apiKey: apiKey, engineID: engineID)
    }

    public static func youTrackConfig(claudeJSONPath: URL = defaultClaudeJSONPath) -> YouTrackConfig? {
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
