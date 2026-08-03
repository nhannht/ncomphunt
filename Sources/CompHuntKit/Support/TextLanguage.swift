import Foundation
import NaturalLanguage

/// A direction display translation could run: from the language the text is
/// written in toward the language the reader reads.
public struct TranslationPair: Equatable, Sendable {
    public let source: Locale.Language
    public let target: Locale.Language

    public init(source: Locale.Language, target: Locale.Language) {
        self.source = source
        self.target = target
    }
}

/// Answers the one question on-demand translation needs answered before any
/// framework is involved: is this text in a language the reader does not
/// read, and if so, which way should a translation run?
///
/// Direction follows the reader rather than being hardcoded Vietnamese to
/// English: a Vietnamese reader gets no button on ybox rows but does on
/// CTFtime rows, an English reader the reverse. Language detection is the one
/// NaturalLanguage capability that works for Vietnamese (lemmas, POS and
/// embeddings all return nothing - measured 2026-08-03), so it is safe to
/// build on where the rest of the framework was not.
public enum TextLanguage {
    /// The pair to translate `text` for `reader`, or nil when no translation
    /// is worth offering: the text is empty, its language cannot be called
    /// with confidence, or it is already the reader's language.
    ///
    /// Detection is dominant-language over the whole text, so a Vietnamese
    /// body whose title carries an English brand name still reads as
    /// Vietnamese. Regional variants collapse to the language code: en-US
    /// readers are not offered a translation of en-GB text.
    public static func translationPair(
        for text: String,
        reader: Locale.Language = Locale.current.language
    ) -> TranslationPair? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= 0.5 else { return nil }

        let source = Locale.Language(identifier: language.rawValue)
        guard source.languageCode != reader.languageCode else { return nil }
        return TranslationPair(source: source, target: reader)
    }
}
