import Testing
@testable import CompHuntKit

@Test func versionIsSet() {
    #expect(!CompHuntKit.version.isEmpty)
}
