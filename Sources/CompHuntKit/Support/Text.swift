import Foundation

/// Plain-text helpers for feed payloads that embed markup.
public enum Text {
    public static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Decodes numeric character references and the common named entities.
    public static func decodeEntities(_ text: String) -> String {
        var result = text
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&nbsp;": " ",
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        while let match = result.range(of: "&#[0-9]+;", options: .regularExpression) {
            let digits = result[match].dropFirst(2).dropLast()
            if let value = UInt32(digits), let scalar = Unicode.Scalar(value) {
                result.replaceSubrange(match, with: String(Character(scalar)))
            } else {
                result.replaceSubrange(match, with: "")
            }
        }
        return result
    }

    public static func plain(_ html: String) -> String {
        decodeEntities(stripTags(html))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
