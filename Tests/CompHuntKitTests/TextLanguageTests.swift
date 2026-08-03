import Foundation
import Testing
@testable import CompHuntKit

@Suite("TextLanguage")
struct TextLanguageTests {
    private let english = Locale.Language(identifier: "en")
    private let vietnamese = Locale.Language(identifier: "vi")

    private let vietnameseText =
        "Cuộc thi sáng tác truyện ngắn dành cho sinh viên trên toàn quốc, giải thưởng hấp dẫn"
    private let englishText =
        "Capture the flag qualifier open to all university teams worldwide"

    @Test func vietnameseTextTranslatesTowardTheEnglishReader() {
        let pair = TextLanguage.translationPair(for: vietnameseText, reader: english)
        #expect(pair?.source.languageCode == vietnamese.languageCode)
        #expect(pair?.target.languageCode == english.languageCode)
    }

    @Test func englishTextIsAlreadyReadableToTheEnglishReader() {
        #expect(TextLanguage.translationPair(for: englishText, reader: english) == nil)
    }

    @Test func vietnameseReaderNeedsNoTranslationOfVietnameseText() {
        #expect(TextLanguage.translationPair(for: vietnameseText, reader: vietnamese) == nil)
    }

    @Test func englishTextTranslatesTowardTheVietnameseReader() {
        let pair = TextLanguage.translationPair(for: englishText, reader: vietnamese)
        #expect(pair?.source.languageCode == english.languageCode)
        #expect(pair?.target.languageCode == vietnamese.languageCode)
    }

    @Test func emptyTextOffersNothing() {
        #expect(TextLanguage.translationPair(for: "   \n  ", reader: english) == nil)
    }

    @Test func regionalReaderVariantsCountAsTheSameLanguage() {
        let reader = Locale.Language(identifier: "en-US")
        #expect(TextLanguage.translationPair(for: englishText, reader: reader) == nil)
    }

    @Test func aVietnameseBodyWithAnEnglishBrandNameStillReadsAsVietnamese() {
        let mixed = "GreyCTF 2026: \(vietnameseText)"
        let pair = TextLanguage.translationPair(for: mixed, reader: english)
        #expect(pair?.source.languageCode == vietnamese.languageCode)
    }
}
