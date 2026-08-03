import CompHuntKit
import SwiftData
import SwiftUI
// @preconcurrency: the macOS 26 SDK leaves TranslationSession un-annotated for
// Sendable, so Swift 6 region isolation rejects calling its nonisolated async
// methods from the MainActor translationTask closure - the exact gap this
// import attribute exists to bridge. The session is only ever used serially
// inside that one closure.
@preconcurrency import Translation

/// Display-only, on-demand translation of one competition's title and details.
///
/// Nothing here touches the store: a refresh that rewrites the source text
/// cannot leave a stale translation behind because there is nowhere for one to
/// live. The original stays one click away behind the same button, and a pair
/// this OS cannot translate simply never grows the button - the ticket's
/// "degrade honestly" is the absence of the affordance, not an error state.
struct TranslationState {
    var configuration: TranslationSession.Configuration?
    var translatedTitle: String?
    var translatedDetails: String?
    /// Whether the translated text is the one on screen right now.
    var showingTranslation = false
    var isRunning = false

    mutating func reset() { self = TranslationState() }

    /// Kicks off (or retries) a translation toward `pair`. The actual work
    /// happens in `translationEffect` when the configuration change lands.
    mutating func arm(for pair: TranslationPair?) {
        guard let pair else { return }
        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: pair.source, target: pair.target)
        } else {
            configuration?.invalidate()
        }
    }

    func title(original: String) -> String {
        showingTranslation ? (translatedTitle ?? original) : original
    }

    func details(original: String) -> String {
        showingTranslation ? (translatedDetails ?? original) : original
    }
}

/// The two user knobs (Settings > Translation). The reading language is the
/// user's own declaration of what they read, defaulting to English - the
/// index's lingua franca - rather than the system locale, so the behavior is
/// the same out of the box on every machine and one picker away from right
/// everywhere else.
enum TranslationPreferences {
    static let autoKey = "translation.auto"
    static let languageKey = "translation.language"
    static let defaultLanguage = "en"
}

/// A change in any of these means the surface's translation is stale: another
/// row selected, the reader's language changed, or auto was toggled.
struct TranslationTaskKey: Hashable {
    let id: PersistentIdentifier
    let language: String
    let auto: Bool
}

/// Decides whether a competition earns translation at all: language detection
/// first (pure, in the kit), then whether this OS can actually translate that
/// pair. Asked per row appearance because availability changes while the app
/// runs - a person can download or remove language models.
enum TranslationOffer {
    static func pair(title: String, details: String,
                     reader: Locale.Language) async -> TranslationPair? {
        guard let pair = TextLanguage.translationPair(
            for: "\(title)\n\(details)", reader: reader) else {
            return nil
        }
        let status = await LanguageAvailability().status(from: pair.source, to: pair.target)
        return status == .unsupported ? nil : pair
    }
}

/// The toggle. Absent when there is nothing to offer. With auto-translate on
/// it reads "Show Original" from the start, because the translation is already
/// on screen; with it off it arms the session on first use and flips between
/// the two texts afterwards without translating again.
struct TranslateButton: View {
    @Binding var state: TranslationState
    let pair: TranslationPair?

    var body: some View {
        if let pair {
            Button(label) {
                if state.showingTranslation {
                    state.showingTranslation = false
                } else if state.translatedTitle != nil || state.translatedDetails != nil {
                    state.showingTranslation = true
                } else {
                    state.arm(for: pair)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(state.isRunning)
        }
    }

    private var label: String {
        if state.isRunning { return "Translating…" }
        return state.showingTranslation ? "Show Original" : "Translate"
    }
}

extension View {
    /// Hosts the translation work for a surface that renders `state`. Attach
    /// once per surface; the task only runs once something arms the
    /// configuration, and a failure quietly leaves the original on screen.
    func translationEffect(_ state: Binding<TranslationState>,
                           title: String,
                           details: String) -> some View {
        translationTask(state.wrappedValue.configuration) { session in
            state.wrappedValue.isRunning = true
            defer { state.wrappedValue.isRunning = false }
            do {
                var requests = [
                    TranslationSession.Request(sourceText: title, clientIdentifier: "title")
                ]
                if !details.isEmpty {
                    requests.append(
                        TranslationSession.Request(sourceText: details, clientIdentifier: "details"))
                }
                let responses = try await session.translations(from: requests)
                for response in responses {
                    switch response.clientIdentifier {
                    case "title": state.wrappedValue.translatedTitle = response.targetText
                    case "details": state.wrappedValue.translatedDetails = response.targetText
                    default: break
                    }
                }
                state.wrappedValue.showingTranslation = true
            } catch {
                state.wrappedValue.showingTranslation = false
            }
        }
    }
}
