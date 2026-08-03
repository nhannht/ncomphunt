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

    /// Keyword lists in match-priority order. Each carries the Vietnamese
    /// spellings too, because ybox titles are Vietnamese and it is the only
    /// lane whose category is not declared by its source.
    ///
    /// The last four lists were added after measuring a live store: 81 rows sat
    /// in `.other`, every one from ybox, and 88% of them named an activity this
    /// enum had no case for. Writing and media come before business and
    /// academic because a prize or an organiser often mentions the latter two -
    /// "Hiep Hoi Doanh Nghiep" is who runs the contest, not what it is.
    ///
    /// Deliberately absent: `hoc bong` (scholarship) and `doanh nghiep`
    /// (enterprise). Both name a PRIZE or an ORGANISER rather than an activity,
    /// and both produced false positives when measured.
    ///
    /// The rule for adding a needle: it must NAME THE ACTIVITY on its own.
    /// Vietnamese writes a compound as separate syllables, so word-anchoring
    /// cannot tell a word from a syllable of a longer word that means something
    /// else. `thơ` is poem, but it is also the second half of `tuổi thơ`
    /// (childhood), which filed a robotics contest as poetry. `ảnh` is photo,
    /// and also the second half of `ảnh hưởng` (influence). `song` is an
    /// English noun and also `song ngữ` (bilingual). All three are gone; the
    /// compounds that do name the activity - `sáng tác thơ`, `nhiếp ảnh`,
    /// `ca khúc` - carry those cases instead. A syllable stays only where no
    /// unrelated compound contains it (`phim`, `múa`, `hát`).
    /// English morphology note: a trailing `*` makes a needle word-INITIAL, so
    /// `photograph*` carries photography, photographer and photographic in one
    /// entry instead of three. Vietnamese needles never use it - Vietnamese
    /// does not inflect, it compounds, and a compound's extra syllables change
    /// the meaning (`ảnh` vs `ảnh hưởng`), which is the exact trap the
    /// word-anchoring exists to close.
    ///
    /// Deliberately absent, measured on the live store 2026-08-03 alongside the
    /// prize/organiser exclusions above: `tài chính` (finance) and `ngân hàng`
    /// (banking) name the ORGANISER as often as the activity - "CLB Kinh Tế và
    /// Tài Chính" hosting a debate flipped an academic row to business. `vẽ`
    /// alone (the compounds `vẽ tranh`, `tranh cổ động` carry the real cases)
    /// and bare `truyền thông`, which names a ministry and a faculty more often
    /// than a contest.
    private static let keywordCategories: [(category: CompetitionCategory, keywords: [String])] = [
        (.ctf, ["*ctf", "capture the flag", "an toàn thông tin", "an ninh mạng"]),
        (.ai, [
            "machine learning", "ai challenge", "data science", "llm",
            "deep learning", "artificial intelligence", "ai ml", "generative ai",
            "trí tuệ nhân tạo", "khoa học dữ liệu", "robotics",
            // Bare `ai` can never be a needle - it is the Vietnamese word for
            // "who" - so the recurring VN contest-name compounds stand in,
            // same allowlist trade as `vietnamContestBrands`.
            "ai race", "ai festival", "ai thực chiến",
        ]),
        (.cp, [
            "competitive programming", "icpc", "informatics olympiad",
            "olympiad in informatics", "coding contest", "programming contest",
            "lập trình", "tin học",
            // Weak fallback: clist.by is overwhelmingly a programming-contest
            // aggregator, so an unmapped clist resource defaults to cp. Listed
            // after ctf and ai so those still win.
            "clist",
        ]),
        (.hackathon, ["hackathon", "hack day", "makeathon", "devpost", "space apps"]),
        (.design, [
            "design*", "ui ux", "ux ui", "illustrat*", "logo", "branding",
            "poster", "architect*", "thiết kế", "vẽ tranh", "mỹ thuật",
            "đồ họa", "đồ hoạ", "hội họa", "hội hoạ", "kiến trúc",
            "tranh cổ động", "sáng tác tranh", "digital art",
        ]),
        (.writing, [
            "viết", "viết luận", "sáng tác thơ", "làm thơ", "bài thơ", "thơ ca",
            "truyện", "truyện ngắn", "tản văn", "tùy bút", "sáng tác văn",
            "slogan", "khẩu hiệu", "essay", "bài viết", "review",
        ]),
        (.media, [
            "nhiếp ảnh", "chụp ảnh", "bộ ảnh", "phim", "phim ngắn", "điện ảnh",
            "video", "clip", "âm nhạc", "ca khúc", "hát", "nhảy", "múa",
            "biểu diễn", "photograph*", "photo", "film", "short film",
            "song contest", "songwriting", "tiktok",
            "cuộc thi ảnh", "anime", "animation", "content creator",
            "đa phương tiện", "sáng kiến truyền thông",
        ]),
        (.business, [
            "khởi nghiệp", "startup", "kinh doanh", "quản trị", "thương mại",
            "business", "case competition", "esg", "pitch", "entrepreneur*",
            "case study", "innovation", "đổi mới sáng tạo",
            "kế toán", "kiểm toán", "môi giới",
        ]),
        (.academic, [
            "hùng biện", "diễn thuyết", "tìm hiểu", "toán học", "trắc nghiệm",
            "kiến thức", "olympic", "olympiad", "speech", "debate", "quiz",
            "public speaking", "học thuật",
        ]),
    ]

    /// Every category the text supports, in the priority order above.
    ///
    /// A competition can genuinely be several things at once. One real row is a
    /// contest for poetry, music AND photography - it is not any one of those,
    /// it is all three, and forcing a single answer means storing something
    /// false. An empty result means nothing matched, which is an honest answer
    /// and becomes `.other`.
    public static func tags(for dto: CompetitionDTO) -> [CompetitionCategory] {
        if let explicit = dto.category {
            return [explicit]
        }
        let host = URL(string: dto.url)?.host()?.lowercased() ?? ""
        let tagText = " \(dto.tags.joined(separator: " ").lowercased()) "
        for (fragment, category) in hostCategories {
            // A source that declares its own kind is authoritative and ends the
            // search - never spend a guess on a row CTFtime already answered.
            if host.contains(fragment) || tagText.contains(fragment) {
                return [category]
            }
        }
        let title = normalized("\(dto.title) \(dto.tags.joined(separator: " "))")
        let fromTitle = matches(in: title)
        if !fromTitle.isEmpty {
            return fromTitle
        }
        // Details are a FALLBACK, never a second haystack merged into the
        // first. A title that names the activity is the organiser speaking
        // precisely; details are marketing prose that name-drops - a real
        // estate contest whose blurb says AI is changing the industry must not
        // become an AI competition. Measured on the live store (2026-08-03):
        // merging the two haystacks flipped the leading tag on rows the title
        // had already answered; consulting details only on a silent title
        // rescued the same rows and flipped none.
        return matches(in: normalized(dto.details))
    }

    private static func matches(in haystack: String) -> [CompetitionCategory] {
        keywordCategories
            .filter { contains(haystack, any: $0.keywords) }
            .map(\.category)
    }

    /// The single category for surfaces that can show only one: the widget dot,
    /// group-by, the menu bar. A projection of `tags`, never a separate
    /// decision, so the two can never disagree.
    public static func category(for dto: CompetitionDTO) -> CompetitionCategory {
        tags(for: dto).first ?? .other
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

    /// VN-specific contest and organizer brands. VN technical contests reach us
    /// from the global aggregators (clist.by, CTFtime, Codeforces, MLContests)
    /// under a non-.vn host and an English title, so the geographic markers above
    /// miss them; these brand tokens catch the well-known ones (VNOI Cup,
    /// WhiteHat, Zalo AI Challenge, SVATTT, and the Efiens / KCSC / Viettel CTF
    /// teams). Limitation: an allowlist only tags brands it enumerates, so a new
    /// VN contest with an unknown name stays .global until its token is added.
    private static let vietnamContestBrands = [
        "vnoi", "whitehat", "zalo", "efiens", "kcsc", "svattt", "viettel",
    ]

    public static func region(for dto: CompetitionDTO) -> Region {
        if let host = URL(string: dto.url)?.host()?.lowercased(),
           host.hasSuffix(".vn") {
            return .vietnam
        }
        let haystack = normalized(
            "\(dto.title) \(dto.location) \(dto.organizer) \(dto.tags.joined(separator: " "))")
        if contains(haystack, any: vietnamKeywords)
            || contains(haystack, any: vietnamContestBrands) {
            return .vietnam
        }
        return .global
    }

    /// Word-anchored containment: the needle is normalised and padded, so it can
    /// only match a whole run of words in an already-normalised haystack.
    ///
    /// This closes a real bug. `ctf` was listed as a bare needle while only the
    /// HAYSTACK carried padding, so `" impactforge "` contained `"ctf"` and a
    /// Devpost project called ImpactForge was filed as a security CTF. The
    /// comment at the top of this file already claimed the keywords were
    /// space-anchored; until now only the haystack was.
    /// A needle prefixed with `*` matches at the END of a word as well as on its
    /// own. CTF events are named `<something>CTF` - picoCTF, BrunnerCTF,
    /// jailCTF, DownUnderCTF - so the token essentially never stands alone and a
    /// strict whole-word rule misses every one of them. Anchoring to the end of
    /// a word still rejects `impactforge`, where `ctf` sits mid-word followed by
    /// `orge`, which is the bug this whole change exists to close.
    ///
    /// A needle suffixed with `*` is the mirror: it matches at the START of a
    /// word, which is where English inflects - `photograph*` reaches
    /// photography, photographer and photographic without listing each form.
    private static func contains(_ haystack: String, any needles: [String]) -> Bool {
        needles.contains { needle in
            if needle.hasPrefix("*") {
                let wordFinal = String(normalized(String(needle.dropFirst())).dropFirst())
                return haystack.contains(wordFinal)
            }
            if needle.hasSuffix("*") {
                let wordInitial = String(normalized(String(needle.dropLast())).dropLast())
                return haystack.contains(wordInitial)
            }
            return haystack.contains(normalized(needle))
        }
    }

    /// Lowercased, every non-alphanumeric flattened to a space, the seam between
    /// letters and digits split, runs collapsed, and padded at both ends so the
    /// first and last words anchor too.
    ///
    /// Punctuation is flattened rather than stripped so `ui/ux` and `tp.hcm`
    /// become `ui ux` and `tp hcm` on BOTH sides and still match. Vietnamese
    /// diacritics are letters to `isLetter`, so `viết` survives intact.
    ///
    /// A year glued to a name is a word boundary too. Contest titles arrive as
    /// `picoCTF2024`, `VNOI2024`, `Hanoi2026` as often as they arrive spaced,
    /// and without the letter-digit split those anchor at neither end: the
    /// haystack holds `ctf2024`, so a needle padded to `ctf ` cannot match.
    /// Splitting the seam fixes every needle at once, on both sides, rather
    /// than adding a second digit-tolerant matching path beside the first.
    private static func normalized(_ text: String) -> String {
        var words = ""
        var previous: Character?
        for character in text.lowercased() {
            guard character.isLetter || character.isNumber else {
                words.append(" ")
                previous = nil
                continue
            }
            if let previous, previous.isNumber != character.isNumber {
                words.append(" ")
            }
            words.append(character)
            previous = character
        }
        return " " + words.split(separator: " ").joined(separator: " ") + " "
    }
}
