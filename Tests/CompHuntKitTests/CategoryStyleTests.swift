import SwiftUI
import Testing
@testable import CompHuntKit

/// Guards the single category mapping against the drift that motivated it:
/// before CategoryStyle, the app and the widget each hardcoded colors and CTF
/// had silently become purple in one and red in the other.
@Suite struct CategoryStyleTests {
    @Test func shortLabelsAreDistinctAndNonEmpty() {
        let labels = CompetitionCategory.allCases.map(\.shortLabel)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }

    @Test func tintForCodeRoundTripsEveryCategory() {
        for category in CompetitionCategory.allCases {
            #expect(CompetitionCategory.tint(forCode: category.shortCode) == category.tint)
        }
    }

    @Test func unknownCodeFallsBackToGray() {
        #expect(CompetitionCategory.tint(forCode: "NOPE") == .gray)
    }
}
