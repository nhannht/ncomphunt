import Foundation
import Testing
@testable import CompHuntKit

/// Fixture-tested against captured `user.info` shapes, no network - the
/// COMP-17 acceptance rule. The OK fixture is the response shape verified
/// live against handle `tourist` when the issue was specced.
@Suite struct CodeforcesRatingTests {
    @Test func parsesARatingFromTheVerifiedResponseShape() throws {
        let fixture = Data("""
        {"status":"OK","result":[{"handle":"tourist","rating":3530,
        "maxRating":4009,"rank":"tourist","contribution":128}]}
        """.utf8)
        #expect(try CodeforcesRating.parse(fixture) == 3530)
    }

    /// An account that never entered a rated round has no `rating` field:
    /// that is the real answer "unrated", not a failure.
    @Test func anUnratedAccountReadsAsZero() throws {
        let fixture = Data("""
        {"status":"OK","result":[{"handle":"fresh","contribution":0}]}
        """.utf8)
        #expect(try CodeforcesRating.parse(fixture) == 0)
    }

    /// The API's own failure shape for a bad handle. Throwing here is what
    /// lets the app layer swallow it silently and leave the cached rating
    /// alone, per the non-fatal contract.
    @Test func aFailedStatusThrows() {
        let fixture = Data("""
        {"status":"FAILED","comment":"handles: User with handle no_such_user_x not found"}
        """.utf8)
        #expect(throws: CodeforcesError.self) {
            try CodeforcesRating.parse(fixture)
        }
    }

    @Test func anEmptyResultThrowsRatherThanInventingARating() {
        let fixture = Data(#"{"status":"OK","result":[]}"#.utf8)
        #expect(throws: CodeforcesError.self) {
            try CodeforcesRating.parse(fixture)
        }
    }

    @Test func garbageBytesThrow() {
        #expect(throws: Error.self) {
            try CodeforcesRating.parse(Data("not json".utf8))
        }
    }
}
