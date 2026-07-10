import Foundation

/// Assigns a category and region to a DTO whose source could not decide.
/// Matching mirrors job-recon's filter: lowercase, space-anchored keywords so
/// short tokens never match inside longer words.
public enum Classifier {

    // MARK: Category

    /// Resource/host fragments -> category. Checked against the URL host and tags.
    private static let hostCategories: [(fragment: String, category: CompetitionCategory)] = [
        ("codeforces.com", .cp), ("atcoder.jp", .cp), ("leetcode.com", .cp),
        ("codechef.com", .cp), ("hackerrank.com", .cp), ("hackerearth.com", .cp),
        ("topcoder.com", .cp), ("codingame.com", .cp), ("icpc.global", .cp),
        ("kaggle.com", .ai), ("aicrowd.com", .ai), ("drivendata.org", .ai),
        ("zindi.africa", .ai), ("huggingface.co", .ai), ("codabench.org", .ai),
        ("ctftime.org", .ctf),
    ]

    private static let ctfKeywords = ["ctf", "capture the flag"]
    private static let cpKeywords = [
        "competitive programming", "icpc", "informatics olympiad",
        "olympiad in informatics", "coding contest", "programming contest",
        // Weak fallback: clist.by is overwhelmingly a programming-contest
        // aggregator, so an unmapped clist resource defaults to cp. Checked
        // after the ctf and ai keyword passes, so those still win.
        "clist",
    ]
    private static let aiKeywords = [
        "machine learning", "ai challenge", "data science", " llm ",
        "deep learning", "artificial intelligence", "ai/ml", "generative ai",
    ]
    private static let designKeywords = [
        "design", "ui/ux", "ux/ui", "illustration", "logo", "branding",
        "poster", "architecture", "photography", "creative",
    ]
    private static let hackathonKeywords = ["hackathon", "hack day", "makeathon", "devpost"]

    public static func category(for dto: CompetitionDTO) -> CompetitionCategory {
        if let explicit = dto.category {
            return explicit
        }
        let host = URL(string: dto.url)?.host()?.lowercased() ?? ""
        let tagText = " \(dto.tags.joined(separator: " ").lowercased()) "
        for (fragment, category) in hostCategories {
            if host.contains(fragment) || tagText.contains(fragment) {
                return category
            }
        }
        let haystack = " \(dto.title) \(dto.tags.joined(separator: " ")) ".lowercased()
        if contains(haystack, any: ctfKeywords) { return .ctf }
        if contains(haystack, any: aiKeywords) { return .ai }
        if contains(haystack, any: cpKeywords) { return .cp }
        if contains(haystack, any: designKeywords) { return .design }
        if contains(haystack, any: hackathonKeywords) { return .hackathon }
        return .other
    }

    // MARK: Region

    /// Vietnam markers. Short tokens ("hcm", "hue") stay space-anchored via the
    /// padded haystack; diacritic and plain spellings are both listed.
    private static let vietnamKeywords = [
        "vietnam", "việt nam", "viet nam", "vietnamese",
        "hà nội", "ha noi", "hanoi",
        "hồ chí minh", "ho chi minh", "hcm", "tphcm", "tp.hcm",
        "sài gòn", "saigon", "sai gon",
        "đà nẵng", "da nang", "danang",
        "cần thơ", "can tho", "huế",
    ]

    public static func region(for dto: CompetitionDTO) -> Region {
        if let host = URL(string: dto.url)?.host()?.lowercased(),
           host.hasSuffix(".vn") {
            return .vietnam
        }
        let haystack = " \(dto.title) \(dto.location) \(dto.organizer) \(dto.tags.joined(separator: " ")) "
            .lowercased()
        if contains(haystack, any: vietnamKeywords) {
            return .vietnam
        }
        return .global
    }

    private static func contains(_ haystack: String, any needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
