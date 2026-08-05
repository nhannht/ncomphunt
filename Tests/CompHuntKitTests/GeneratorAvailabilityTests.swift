import FoundationModels
import Testing
@testable import CompHuntKit

/// The model is never invoked here. These tests pin the pure mapping from the
/// OS's unavailability reason to what a person is told and whether an
/// open-settings affordance is offered - the decision COMP-50 exists to get
/// right, because a wrong `fixableInSettings` either hides the one actionable
/// case or sends people to Settings for something Settings cannot change.
@Suite struct GeneratorAvailabilityMapping {
    @Test func everyReasonExplainsItself() {
        let reasons: [SystemLanguageModel.Availability.UnavailableReason] =
            [.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady]
        for reason in reasons {
            guard case .unavailable(let text, _) = NLFilterGenerator.status(for: reason)
            else {
                Issue.record("\(reason) mapped to .available")
                continue
            }
            #expect(!text.isEmpty)
        }
    }

    @Test func onlyTheSwitchedOffFeatureIsFixableInSettings() {
        // Ineligible hardware has no fix; a preparing model fixes itself.
        // A settings visit changes exactly one of the three answers.
        #expect(NLFilterGenerator.status(for: .appleIntelligenceNotEnabled)
            == .unavailable(
                reason: "Turn on Apple Intelligence in Settings to use natural-language search.",
                fixableInSettings: true))
        guard case .unavailable(_, let eligibleFix) =
                NLFilterGenerator.status(for: .deviceNotEligible),
              case .unavailable(_, let readyFix) =
                NLFilterGenerator.status(for: .modelNotReady)
        else {
            Issue.record("an unavailable reason mapped to .available")
            return
        }
        #expect(!eligibleFix)
        #expect(!readyFix)
    }
}
