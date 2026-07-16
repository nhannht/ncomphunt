import Foundation
import Testing
@testable import CompHuntKit

@Suite struct ClistParsing {
    @Test func parsesAndSkipsCTFtimeResource() throws {
        let dtos = try ClistSource.parse(try fixture("clist", "json"))
        #expect(dtos.count == 2)
        #expect(!dtos.contains { $0.url.contains("ctftime.org") })
    }

    @Test func fieldsAndDates() throws {
        let dtos = try ClistSource.parse(try fixture("clist", "json"))
        let round = try #require(dtos.first { $0.title.contains("Codeforces Round") })
        #expect(round.source == "clist")
        #expect(round.organizer == "codeforces.com")
        #expect(round.startDate != nil)
        #expect(round.endDate != nil)
        if let start = round.startDate, let end = round.endDate {
            #expect(end.timeIntervalSince(start) == 7200)
        }
    }

    @Test func classifierRoutesResources() throws {
        let dtos = try ClistSource.parse(try fixture("clist", "json"))
        let round = try #require(dtos.first { $0.title.contains("Codeforces") })
        let arc = try #require(dtos.first { $0.title.contains("ARC Prize") })
        #expect(Classifier.category(for: round) == .cp)
        #expect(Classifier.category(for: arc) == .ai)
    }

    @Test func unknownResourceDefaultsToCP() {
        let dto = CompetitionDTO(
            source: "clist", title: "The 4th Universal Cup", url: "https://ucup.ac/r/45",
            tags: ["ucup.ac", "clist"]
        )
        #expect(Classifier.category(for: dto) == .cp)
    }

    @Test func missingCredentialsThrowsSkip() async {
        let source = ClistSource(credentials: nil)
        await #expect(throws: SourceSkipped.self) {
            _ = try await source.fetch()
        }
    }
}

@Suite struct SecretsReading {
    private func tempFile(_ name: String, _ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func readsClistCredentials() throws {
        let path = try tempFile("secrets.yml", """
            # comment
            CLIST_USERNAME: "nhannht"
            CLIST_API_KEY: "abc123"
            """)
        let creds = SecretsReader.clistCredentials(
            secretsPath: path, store: InMemoryCredentialStore())
        #expect(creds?.username == "nhannht")
        #expect(creds?.apiKey == "abc123")
    }

    @Test func rejectsPlaceholdersAndMissingFile() throws {
        let placeholder = try tempFile("secrets.yml", """
            CLIST_USERNAME: "your-clist-username"
            CLIST_API_KEY: "your-clist-api-key"
            """)
        #expect(SecretsReader.clistCredentials(
            secretsPath: placeholder, store: InMemoryCredentialStore()) == nil)

        let missing = URL(fileURLWithPath: "/nonexistent/secrets.yml")
        #expect(SecretsReader.clistCredentials(
            secretsPath: missing, store: InMemoryCredentialStore()) == nil)
    }

    @Test func readsYouTrackConfigAndStripsMCPSuffix() throws {
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

extension ClistCredentials: Equatable {
    public static func == (lhs: ClistCredentials, rhs: ClistCredentials) -> Bool {
        lhs.username == rhs.username && lhs.apiKey == rhs.apiKey
    }
}
