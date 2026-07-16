import Foundation
import Testing
@testable import CompHuntKit

/// Dictionary-backed store for tests; never touches the real Keychain.
final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [CredentialKey: String]

    init(_ values: [CredentialKey: String] = [:]) {
        self.values = values
    }

    func get(_ key: CredentialKey) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func set(_ value: String?, for key: CredentialKey) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
}

@Suite struct CredentialResolution {
    private func tempFile(_ name: String, _ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func storeValueWinsOverFile() throws {
        let path = try tempFile("secrets.yml", """
            CLIST_USERNAME: "file-user"
            CLIST_API_KEY: "file-key"
            """)
        let store = InMemoryCredentialStore([
            .CLIST_USERNAME: "store-user", .CLIST_API_KEY: "store-key",
        ])
        let creds = SecretsReader.clistCredentials(secretsPath: path, store: store)
        #expect(creds?.username == "store-user")
        #expect(creds?.apiKey == "store-key")
    }

    @Test func fileFallbackWhenStoreEmpty() throws {
        let path = try tempFile("secrets.yml", """
            CLIST_USERNAME: "file-user"
            CLIST_API_KEY: "file-key"
            """)
        let creds = SecretsReader.clistCredentials(
            secretsPath: path, store: InMemoryCredentialStore())
        #expect(creds?.username == "file-user")
        #expect(creds?.apiKey == "file-key")
    }

    @Test func placeholderAndEmptyInStoreFallThroughToFile() throws {
        let path = try tempFile("secrets.yml", """
            CLIST_USERNAME: "file-user"
            CLIST_API_KEY: "file-key"
            """)
        let store = InMemoryCredentialStore([
            .CLIST_USERNAME: "your-clist-username", .CLIST_API_KEY: "",
        ])
        let creds = SecretsReader.clistCredentials(secretsPath: path, store: store)
        #expect(creds?.username == "file-user")
        #expect(creds?.apiKey == "file-key")
    }

    @Test func placeholderInFileReturnsNil() throws {
        let path = try tempFile("secrets.yml", """
            CLIST_USERNAME: "your-clist-username"
            CLIST_API_KEY: "your-clist-api-key"
            """)
        let creds = SecretsReader.clistCredentials(
            secretsPath: path, store: InMemoryCredentialStore())
        #expect(creds == nil)
    }

    @Test func braveAndGoogleResolveFromStore() throws {
        let path = try tempFile("secrets.yml", "BRAVE_API_KEY: \"file-brave\"")
        let store = InMemoryCredentialStore([
            .BRAVE_API_KEY: "store-brave",
            .GOOGLE_CSE_KEY: "store-gkey", .GOOGLE_CSE_CX: "store-cx",
        ])
        #expect(SecretsReader.braveKey(secretsPath: path, store: store) == "store-brave")
        let cse = SecretsReader.googleCSE(secretsPath: path, store: store)
        #expect(cse?.apiKey == "store-gkey")
        #expect(cse?.engineID == "store-cx")
    }

    @Test func youTrackConfigFromStoreTrimsSlashAndStripsBearer() throws {
        let store = InMemoryCredentialStore([
            .YOUTRACK_BASE_URL: "https://yt.example.com/",
            .YOUTRACK_TOKEN: "Bearer perm:token123",
        ])
        let missing = URL(fileURLWithPath: "/nonexistent/claude.json")
        let config = SecretsReader.youTrackConfig(claudeJSONPath: missing, store: store)
        #expect(config?.baseURL == "https://yt.example.com")
        #expect(config?.token == "perm:token123")
    }

    @Test func youTrackConfigFileFallbackPreserved() throws {
        let path = try tempFile("claude.json", """
            {
              "mcpServers": {
                "youtrack": {
                  "type": "http",
                  "url": "https://yt.example.com/mcp",
                  "headers": { "Authorization": "Bearer perm:token123" }
                }
              }
            }
            """)
        let config = SecretsReader.youTrackConfig(
            claudeJSONPath: path, store: InMemoryCredentialStore())
        #expect(config?.baseURL == "https://yt.example.com")
        #expect(config?.token == "perm:token123")
    }
}
