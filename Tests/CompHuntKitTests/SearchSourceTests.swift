import Foundation
import Testing
@testable import CompHuntKit

@Suite struct BraveParsing {
    private let query = SearchQuery(text: "hackathon Vietnam 2026", hint: .hackathon)

    @Test func keepsOnlyRealLeads() throws {
        let dtos = try BraveSearchSource.parse(try fixture("brave", "json"), query: query)
        // Covered host (ctftime.org), wikipedia, and the keywordless cafe
        // article are all gated out.
        #expect(dtos.count == 1)
        let lead = try #require(dtos.first)
        #expect(lead.source == "brave")
        #expect(lead.title == "Vietnam AI Hackathon 2026 - Registration open")
        #expect(lead.category == .hackathon)
        #expect(lead.tags.contains("search"))
        #expect(lead.registrationDeadline == nil)
    }

    @Test func stripsHighlightMarkupFromSnippet() throws {
        let dtos = try BraveSearchSource.parse(try fixture("brave", "json"), query: query)
        let lead = try #require(dtos.first)
        #expect(!lead.details.contains("<strong>"))
        #expect(lead.details.contains("hackathon"))
    }

    @Test func vietnamRegionDetected() throws {
        let dtos = try BraveSearchSource.parse(try fixture("brave", "json"), query: query)
        let lead = try #require(dtos.first)
        #expect(Classifier.region(for: lead) == .vietnam)
    }

    @Test func missingKeyThrowsSkip() async {
        let source = BraveSearchSource(apiKey: nil)
        await #expect(throws: SourceSkipped.self) {
            _ = try await source.fetch()
        }
    }
}

@Suite struct GoogleCSEParsing {
    private let query = SearchQuery(text: "design contest 2026 deadline", hint: .design)

    @Test func keepsOnlyRealLeadsAndDecodesEntities() throws {
        let dtos = try GoogleSearchSource.parse(try fixture("googlecse", "json"), query: query)
        #expect(dtos.count == 2)
        #expect(dtos.allSatisfy { $0.source == "googlesearch" && $0.category == .design })
        let awards = try #require(dtos.first { $0.url.contains("awards.example.com") })
        #expect(awards.title == "Global Design Contest 2026 & Awards")
    }

    @Test func missingConfigThrowsSkip() async {
        let source = GoogleSearchSource(config: nil)
        await #expect(throws: SourceSkipped.self) {
            _ = try await source.fetch()
        }
    }
}

@Suite struct SearchHitGates {
    private let query = SearchQuery(text: "CTF competition 2026 registration", hint: .ctf)

    @Test func subdomainOfCoveredHostIsDropped() {
        let hit = SearchHit(
            title: "Some CTF competition",
            url: "https://blog.devpost.com/some-ctf",
            snippet: "A competition on a covered host's subdomain.")
        #expect(SearchHitMapper.dto(from: hit, source: "brave", query: query) == nil)
    }

    @Test func wwwPrefixDoesNotEvadeExclusion() {
        let hit = SearchHit(
            title: "Contest listing", url: "https://www.clist.by/standings",
            snippet: "contest aggregation")
        #expect(SearchHitMapper.dto(from: hit, source: "brave", query: query) == nil)
    }

    @Test func vietnameseKeywordCounts() throws {
        let hit = SearchHit(
            title: "Cuộc thi An toàn thông tin sinh viên",
            url: "https://aseanctf.example.vn",
            snippet: "Vòng loại trực tuyến.")
        let dto = try #require(SearchHitMapper.dto(from: hit, source: "googlesearch", query: query))
        #expect(dto.category == .ctf)
    }

    @Test func unparsableURLIsDropped() {
        let hit = SearchHit(title: "Contest", url: "", snippet: "a contest")
        #expect(SearchHitMapper.dto(from: hit, source: "brave", query: query) == nil)
    }

    @Test func queryCatalogInjectsYear() {
        let now = ISO8601DateFormatter().date(from: "2027-03-01T00:00:00Z")!
        let queries = SearchCatalog.queries(now: now)
        #expect(!queries.isEmpty)
        #expect(queries.allSatisfy { $0.text.contains("2027") })
    }
}

@Suite struct SearchSecretsReading {
    private func tempFile(_ contents: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "comphunt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "secrets.yml")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func readsBraveAndGoogleKeys() throws {
        let path = try tempFile("""
            BRAVE_API_KEY: "brave123"
            GOOGLE_CSE_KEY: "google456"
            GOOGLE_CSE_CX: "cx789"
            """)
        #expect(SecretsReader.braveKey(secretsPath: path) == "brave123")
        let cse = SecretsReader.googleCSE(secretsPath: path)
        #expect(cse?.apiKey == "google456")
        #expect(cse?.engineID == "cx789")
    }

    @Test func rejectsPlaceholdersAndPartialConfig() throws {
        let placeholder = try tempFile("""
            BRAVE_API_KEY: "your-brave-api-key"
            GOOGLE_CSE_KEY: "google456"
            """)
        #expect(SecretsReader.braveKey(secretsPath: placeholder) == nil)
        // cx missing: the pair is incomplete, so the source must skip.
        #expect(SecretsReader.googleCSE(secretsPath: placeholder) == nil)
    }
}
