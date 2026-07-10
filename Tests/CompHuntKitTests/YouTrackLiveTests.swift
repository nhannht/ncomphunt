import Foundation
import Testing
@testable import CompHuntKit

/// Live integration test, off by default: creates a real COMP issue.
/// Run with: COMPHUNT_LIVE_YOUTRACK=1 swift test --filter YouTrackLive
@Suite struct YouTrackLive {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["COMPHUNT_LIVE_YOUTRACK"] == "1"))
    func createsRealIssue() async throws {
        let client = try #require(YouTrackClient())
        let issueID = try await client.createIssue(
            summary: "CompHunt self-test (safe to delete)",
            description: "Created by the CompHunt live YouTrack test.\n\n_Filed by CompHunt._")
        print("[live-test] created \(issueID)")
        #expect(issueID.hasPrefix("COMP-"))
    }
}
