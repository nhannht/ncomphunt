import Foundation
import Testing
@testable import CompHuntKit

@Suite struct SecretsImport {
    private func tempYAML(_ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "secrets.yml")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func importsValidKeysSkippingPlaceholdersEmptiesAndUnknowns() throws {
        let url = try tempYAML("""
            CLIST_USERNAME: "real-user"
            CLIST_API_KEY: "real-key"
            BRAVE_API_KEY: ""
            GOOGLE_CSE_KEY: "your-google-key"
            GOOGLE_CSE_CX: "real-cx"
            UNKNOWN_KEY: "ignored"
            """)
        let store = InMemoryCredentialStore()
        let count = SecretsImporter.importSecretsYAML(at: url, into: store)
        #expect(count == 3)
        #expect(store.get(.CLIST_USERNAME) == "real-user")
        #expect(store.get(.CLIST_API_KEY) == "real-key")
        #expect(store.get(.GOOGLE_CSE_CX) == "real-cx")
        #expect(store.get(.BRAVE_API_KEY) == nil)   // empty skipped
        #expect(store.get(.GOOGLE_CSE_KEY) == nil)  // placeholder skipped
    }

    @Test func missingFileImportsNothing() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/secrets.yml")
        let store = InMemoryCredentialStore()
        #expect(SecretsImporter.importSecretsYAML(at: url, into: store) == 0)
    }
}
