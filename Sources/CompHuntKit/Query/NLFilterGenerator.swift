import Foundation
import FoundationModels

/// Why a natural-language query could not be turned into a filter.
///
/// Every case carries text fit to show a person. None of them leave the list in
/// a changed state: a failed generation must be a no-op, not a half-applied
/// filter.
public enum NLFilterError: LocalizedError {
    /// The sentence could not be resolved into a filter. Rephrasing may work.
    case notUnderstood
    /// The model is momentarily busy. The same query may succeed shortly.
    case busy
    /// The model is not usable on this device right now.
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notUnderstood:
            "Could not turn that into a filter. Try naming a kind of competition, a region, or a timeframe."
        case .busy:
            "The on-device model is busy. Try again in a moment."
        case .unavailable(let reason):
            reason
        }
    }
}

/// Turns a sentence into a `SearchQuery` using the on-device model.
///
/// Runs entirely on this device: no API key, no account, no request leaves the
/// machine, and there is no per-query cost.
///
/// Non-determinism is acceptable here in a way it would not be for a ranking
/// score. The person sees the resolved filter immediately, as editable chips,
/// and rephrases if it read them wrong. A score that moved between refreshes
/// would silently reshuffle a list nobody asked to reshuffle.
public struct NLFilterGenerator: QueryGenerating {
    public init() {}

    public var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: nil
        case .unavailable(let reason): Self.explain(reason)
        }
    }

    private static let instructions = """
        You turn a person's sentence into a filter over a list of competitions.
        The list holds competitive programming contests, security CTFs, AI and \
        machine learning competitions, hackathons, and design contests, from \
        Vietnam and worldwide.

        Fill in only what the sentence actually says. Leave a field empty when \
        the person did not mention it - do not guess a region, a timeframe, or \
        a category that was not asked for.

        Fill in eventName ONLY when the person named one particular event, \
        brand, or organizer, such as Zalo or Codeforces. Leave it empty \
        otherwise. A word that describes a kind of competition, a place, or a \
        time is already captured by the other fields, and repeating it here \
        would look for that phrase in competition titles, where it does not \
        appear. Most requests have no eventName at all.
        """

    public func generate(from text: String, now: Date) async throws -> SearchQuery {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchQuery() }

        // Availability is re-checked here, not only in the UI. The UI hides the
        // affordance when the model is unusable, but Apple Intelligence can be
        // switched off between the view rendering and this call.
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw NLFilterError.unavailable(Self.explain(reason))
        }

        do {
            return try await resolve(trimmed, now: now, session: LanguageModelSession(instructions: Self.instructions))
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                // The session carries no history worth preserving - each query
                // is independent - so a fresh one is the whole recovery.
                return try await resolve(
                    trimmed, now: now,
                    session: LanguageModelSession(instructions: Self.instructions))
            case .rateLimited, .concurrentRequests:
                throw NLFilterError.busy
            case .assetsUnavailable:
                throw NLFilterError.unavailable(
                    "The on-device model is still downloading. Try again later.")
            case .unsupportedLanguageOrLocale:
                throw NLFilterError.unavailable(
                    "The on-device model does not support this language yet.")
            default:
                // guardrailViolation, refusal, decodingFailure, unsupportedGuide.
                // All mean the same thing to the person: this sentence did not
                // become a filter, and nothing changed.
                throw NLFilterError.notUnderstood
            }
        }
    }

    private func resolve(
        _ text: String, now: Date, session: LanguageModelSession
    ) async throws -> SearchQuery {
        let response = try await session.respond(to: text, generating: GeneratedQuery.self)
        return SearchQuery(response.content, from: text, now: now)
    }

    private static func explain(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            "This device cannot run Apple Intelligence, so natural-language search is unavailable."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to use natural-language search."
        case .modelNotReady:
            "Apple Intelligence is still preparing. Try again shortly."
        @unknown default:
            "Natural-language search is unavailable on this device right now."
        }
    }
}
