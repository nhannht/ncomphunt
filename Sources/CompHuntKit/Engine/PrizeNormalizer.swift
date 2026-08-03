import Foundation
import SwiftData
import Synchronization

/// One comparable value extracted from a free-text prize string.
///
/// `topPrizeUSD` is the max single amount found, because "what can I win" is
/// the ranking-relevant figure - a tiered list resolves to its first place.
/// `totalPoolUSD` fills only when a pool keyword marks the amount, and is a
/// secondary signal: a row that names only a pool still ranks by it.
public struct PrizeValue: Sendable, Equatable {
    /// Where the value came from. A `declared` value was parsed from the prize
    /// field a source served; an `inferred` one from the row's title (ybox
    /// embeds amounts in headlines and serves no prize field at all). The
    /// distinction exists so a future scorer can discount inferred values.
    public enum Confidence: Sendable, Equatable {
        case declared
        case inferred
    }

    public var topPrizeUSD: Double?
    public var totalPoolUSD: Double?
    /// Prize-list segments that name a non-cash prize (swag, internships,
    /// licenses, domains). Informational, never priced, never ranked.
    public var nonCash: [String]
    public var raw: String
    public var confidence: Confidence

    /// True when parsing found anything at all - the trigger for the title
    /// fallback is this being false on the prize field.
    public var hasSignal: Bool {
        topPrizeUSD != nil || totalPoolUSD != nil || !nonCash.isEmpty
    }

    /// The ranking projection: top prize, else pool, else nothing.
    public var rankUSD: Double? { topPrizeUSD ?? totalPoolUSD }

    /// One shared presentation line, e.g. "≈ $384 top prize · $70,343 pool".
    /// Fixed `en_US` locale so output is machine-independent, same reasoning
    /// as the translation default: out-of-the-box behavior identical on every
    /// machine. Whole dollars - the FX table is approximate, cents would be
    /// false precision.
    public var summaryLine: String? {
        let style = FloatingPointFormatStyle<Double>.Currency(
            code: "USD", locale: Locale(identifier: "en_US"))
            .precision(.fractionLength(0))
        switch (topPrizeUSD, totalPoolUSD) {
        case (nil, nil):
            return nil
        case (let top?, nil):
            return "≈ \(top.formatted(style)) top prize"
        case (nil, let pool?):
            return "≈ \(pool.formatted(style)) pool"
        case (let top?, let pool?):
            return "≈ \(top.formatted(style)) top · \(pool.formatted(style)) pool"
        }
    }

    /// Compact form for narrow surfaces (the table column): "$12K", "$384".
    public var compactUSD: String? {
        guard let value = rankUSD else { return nil }
        let style = FloatingPointFormatStyle<Double>.Currency(
            code: "USD", locale: Locale(identifier: "en_US"))
            .notation(.compactName)
            .precision(.significantDigits(1...3))
        return value.formatted(style)
    }
}

/// Turns heterogeneous prize strings into one comparable USD number.
///
/// Pure, deterministic, total: same string in, same value out, on every
/// machine, and no input can throw. Deliberately NOT model-backed - the value
/// is recomputed on read (never persisted), so a nondeterministic source would
/// reshuffle the ranked list between refreshes and between machines, which is
/// the exact instability COMP-5 forbids. Ambiguity resolves to nil rather than
/// to a guess: a wrong number silently corrupts the ranking, a nil just leaves
/// the row unranked by value.
///
/// The engine EXTRACTS money tokens, it never comprehends strings. A money
/// token is a number a currency marker touches (the adjacency rule); text that
/// carries no token - "TBA", "TDB", "See event.", "CANCELLED", a cooking
/// contest, a model number like WH-1000XM5 - simply yields nothing, so novel
/// garbage is handled by default rather than by enumeration.
public enum PrizeNormalizer {

    // MARK: Currency tables

    /// Approximate FX rates to USD, hardcoded on purpose: no network, so the
    /// value is identical offline and in tests, and a rate error of a few
    /// percent cannot reorder competitions whose prizes differ by the amounts
    /// that matter here. Refreshed per release (last: 2026-08). Unknown
    /// currency = no token, never a guess.
    private static let usdRates: [String: Double] = [
        "USD": 1.0,
        "EUR": 1.08,
        "GBP": 1.28,
        "JPY": 0.0065,
        "INR": 0.0115,
        "VND": 0.000039,
        "KRW": 0.00072,
        "SGD": 0.75,
        "NZD": 0.60,
        "AUD": 0.66,
        "BRL": 0.18,
        "CAD": 0.73,
        "TWD": 0.031,
        "CNY": 0.14,
    ]
    // Deliberately unmapped: crypto (BTC, SATS - a rate pinned per release
    // would be wrong by double digits between releases) and currencies the
    // corpus has not shown in a cash position. Unknown currency = honest nil.

    /// Markers glued to the number ("$300", "NZ$400", "Rs.20,000", "670$").
    /// Longest match wins, so `NZ$` resolves before `$` can claim it.
    /// `¥` defaults to JPY; a CNY prize would need an explicit CNY code, which
    /// is the safe side of that ambiguity.
    private static let attachedMarkers: [(symbol: String, code: String)] = [
        ("US$", "USD"), ("NZ$", "NZD"), ("AU$", "AUD"), ("S$", "SGD"),
        ("A$", "AUD"), ("R$", "BRL"), ("RS.", "INR"), ("RS", "INR"),
        ("$", "USD"), ("£", "GBP"), ("€", "EUR"), ("¥", "JPY"),
        ("₹", "INR"), ("₫", "VND"), ("Đ", "VND"),
    ]

    /// Markers standing as their own word beside the number ("USD 10,000",
    /// "10000 VND", "500 USD", "200.000 Đồng").
    private static let wordMarkers: [String: String] = [
        "usd": "USD", "dollar": "USD", "dollars": "USD",
        "eur": "EUR", "euro": "EUR", "euros": "EUR",
        "gbp": "GBP", "pound": "GBP", "pounds": "GBP",
        "jpy": "JPY", "yen": "JPY",
        "inr": "INR", "rupee": "INR", "rupees": "INR", "rs": "INR", "rs.": "INR",
        "vnd": "VND", "vnđ": "VND", "đồng": "VND", "dong": "VND",
        "krw": "KRW", "won": "KRW", "yên": "JPY",
        "sgd": "SGD", "nzd": "NZD", "aud": "AUD", "brl": "BRL", "cad": "CAD",
        "ntd": "TWD", "twd": "TWD", "rmb": "CNY", "cny": "CNY",
    ]

    /// Scale words beside the number ("50 triệu", "2 million", "1 lakh") and
    /// their non-diacritic spellings. Bare `ty`/`ti` are safe ONLY because a
    /// token already requires a currency marker - a scale word alone never
    /// creates one, so "party time" and "ti taste" can never produce money.
    private static let wordScales: [String: Double] = [
        "thousand": 1e3, "nghìn": 1e3, "nghin": 1e3, "ngàn": 1e3, "ngan": 1e3,
        "million": 1e6, "triệu": 1e6, "trieu": 1e6,
        "billion": 1e9, "tỷ": 1e9, "tỉ": 1e9, "ty": 1e9, "ti": 1e9,
        "lakh": 1e5, "crore": 1e7,
        "k": 1e3, "m": 1e6,
    ]

    /// Scales glued to the number ("$5k", "1.5M").
    private static let attachedScales: [String: Double] = [
        "k": 1e3, "m": 1e6,
    ]

    /// A number within reach of these words is a cost, not a prize.
    /// English words match singly; Vietnamese `lệ phí` (entrance fee) matches
    /// as a consecutive pair. Bare `phí` is deliberately NOT here: every ybox
    /// title ends in "(Miễn Phí Tham Dự)" - free to enter - and a bare-word
    /// guard would kill the whole lane this normalizer exists to read.
    private static let feeWords: Set<String> = ["fee", "fees", "registration"]
    private static let feePairs: [(String, String)] = [("lệ", "phí")]

    /// A token within reach of these (before it, same line) is a pool total,
    /// not a single winnable amount. "tổng" = total.
    private static let poolWords: Set<String> = [
        "total", "pool", "tổng", "totalling", "totaling",
    ]

    /// Pool words that also work AFTER the token, in a tighter window:
    /// "$7,600 worth of prizes" is a whole-pot valuation. The window is 2
    /// because a wide trailing reach let a totals clause claim first-place
    /// amounts in tiered lists.
    private static let poolWordsAfter: Set<String> = ["worth", "total", "pool"]

    /// "Worth" BEFORE a token marks the valuation of a non-cash item -
    /// "Certificate (Worth $99)", "vouchers (worth $180 AUD each)". The
    /// amount prices the trinket, not a winnable cash prize, so the token is
    /// dropped and the line stays eligible for `nonCash`.
    private static let valuationWords: Set<String> = ["worth"]
    private static let valuationPairs: [(String, String)] = [("trị", "giá")]

    /// Words that mark a no-token segment as naming a non-cash prize.
    private static let nonCashWords: Set<String> = [
        "swag", "internship", "internships", "voucher", "vouchers",
        "credit", "credits", "merch", "merchandise", "subscription",
        "license", "licenses", "licence", "licences", "domain", "domains",
        "certificate", "certificates", "trophy", "trophies", "medal", "medals",
        "hoodie", "hoodies", "tshirt", "t-shirts", "t-shirt", "shirts",
        "sticker", "stickers", "goodies", "hardware",
    ]

    // MARK: API

    /// Parses one prize string. Pure and total - never throws, and arbitrary
    /// garbage yields an empty value rather than an error.
    public static func normalize(_ raw: String) -> PrizeValue {
        var top: Double?
        var pool: Double?
        var nonCash: [String] = []

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
            var foundToken = false
            for index in words.indices {
                guard let usd = tokenUSD(at: index, in: words) else { continue }
                // A valuation prices a non-cash item, not a winnable amount:
                // the token is dropped WITHOUT claiming the line, so the
                // certificate it valued can still land in `nonCash` below.
                if isValuation(index, in: words) { continue }
                foundToken = true
                if isNearFee(index, in: words) { continue }
                if isPool(index, in: words) {
                    pool = max(pool ?? 0, usd)
                } else {
                    top = max(top ?? 0, usd)
                }
            }
            if !foundToken, namesNonCash(words) {
                let segment = line.trimmingCharacters(in: .whitespaces)
                nonCash.append(String(segment.prefix(80)))
            }
        }
        return PrizeValue(
            topPrizeUSD: top, totalPoolUSD: pool, nonCash: nonCash,
            raw: raw, confidence: .declared)
    }

    /// The prize field first; when it yields nothing at all, the title -
    /// tagged `.inferred`. ybox serves no prize field and embeds the amount in
    /// the headline ("Cơ Hội Nhận 10.000.000 VNĐ Từ Cuộc Thi..."), which is
    /// 40% of the live store, so without this fallback the normalizer would
    /// never see the lane the Vietnamese tables exist for. A title is not a
    /// prize LIST, so the fallback keeps cash signal only - collecting title
    /// fragments as `nonCash` would junk the field with marketing copy.
    /// `details` stays out entirely: prose name-drops numbers the way it
    /// name-drops AI (the classifier learned this the measured way).
    public static func value(prize: String, title: String) -> PrizeValue {
        let declared = normalize(prize)
        if declared.hasSignal {
            return declared
        }
        var inferred = normalize(title)
        inferred.confidence = .inferred
        inferred.nonCash = []
        return inferred
    }

    /// `value(prize:title:)` through a bounded memo. Sorting recomputes the
    /// value O(n log n) times per pass inside the query pipeline; the function
    /// is pure, so caching cannot change behavior, only cost.
    public static func cachedValue(prize: String, title: String) -> PrizeValue {
        let key = prize + "\u{0}" + title
        if let hit = cache.withLock({ $0[key] }) {
            return hit
        }
        let value = value(prize: prize, title: title)
        cache.withLock {
            if $0.count > 2048 { $0.removeAll(keepingCapacity: true) }
            $0[key] = value
        }
        return value
    }

    private static let cache = Mutex<[String: PrizeValue]>([:])

    // MARK: Token extraction

    /// The adjacency rule: the word at `index` is a money token only when it
    /// contains a number AND a currency marker touches it - glued on
    /// ("$300", "670$", "Rs.20,000") or standing in the neighbor window
    /// ("USD 10,000", "500 USD", "50 triệu VNĐ", "$1.5 million"). This is
    /// what keeps "12 Teams", "Top 3", a bare year and a model number out:
    /// numbers are everywhere in prize prose, money markers are not.
    private static func tokenUSD(at index: Int, in words: [String]) -> Double? {
        let word = trimPunctuation(words[index])
        guard word.contains(where: \.isNumber) else { return nil }

        guard let run = numberRun(in: word) else { return nil }
        let prefix = String(word[word.startIndex..<run.lowerBound])
        let suffix = String(word[run.upperBound...])

        var code: String?
        var scale = 1.0
        // A bare `$` is generic "dollars": an explicit code beside the number
        // outranks it, so "$180 AUD" prices as AUD, not USD. Only the bare
        // symbol yields - `NZ$` and friends already name their currency.
        var genericDollar = false

        // Glued prefix/suffix must BE a marker (or a scale, for suffixes) -
        // symbol ("$300", "670$"), or code ("50,000,000KRW", "$3200AUD").
        // Unrecognised glue vetoes the token outright: in "WH-1000XM5" the
        // digits are part of an identifier, and a markerless pass over its
        // neighbors would be reading someone else's number.
        if !prefix.isEmpty {
            guard let matched = gluedMarker(prefix) else { return nil }
            code = matched
            genericDollar = prefix == "$"
        }
        if !suffix.isEmpty {
            if let matched = gluedMarker(suffix) {
                if code == nil || genericDollar {
                    code = matched
                    genericDollar = false
                }
            } else if let attached = attachedScales[suffix.lowercased()] {
                scale = attached
            } else {
                return nil
            }
        }

        guard var amount = parseAmount(String(word[run])) else { return nil }

        // Neighbor window: one word back, two forward - enough for
        // "USD 10,000", "10000 VND", "50 triệu VNĐ", "$1.5 million" and a
        // symbol standing as its own word ("₹ 10,000", "22,90 €"), small
        // enough that a marker cannot claim a number across a clause.
        if index > 0, code == nil {
            code = markerWord(words[index - 1])
        }
        var sawWordScale = false
        for step in 1...2 where index + step < words.count {
            let neighbor = normalizedWord(words[index + step])
            if !sawWordScale, scale == 1.0, let wordScale = wordScales[neighbor] {
                scale = wordScale
                sawWordScale = true
                continue
            }
            if code == nil || genericDollar,
               let explicit = markerWord(words[index + step]) {
                code = explicit
            }
            break
        }

        guard let code, let rate = usdRates[code] else { return nil }
        amount *= scale
        let usd = amount * rate
        // A "prize" above ten billion dollars is a parse gone wrong, not a
        // prize. Nil is the honest answer.
        guard usd < 1e10 else { return nil }
        return usd
    }

    /// The maximal digits-and-separators run, trimmed to start and end on a
    /// digit so trailing sentence punctuation never joins the number.
    private static func numberRun(in word: String) -> Range<String.Index>? {
        guard let first = word.firstIndex(where: \.isNumber) else { return nil }
        var end = first
        var index = first
        while index < word.endIndex,
              word[index].isNumber || word[index] == "." || word[index] == "," {
            if word[index].isNumber { end = index }
            index = word.index(after: index)
        }
        return first..<word.index(after: end)
    }

    /// Separator disambiguation, deterministic and fixture-pinned:
    ///
    /// - both `.` and `,` present: the LAST separator is the decimal mark and
    ///   the other must form 3-digit groups ("1,234.56", "1.234,56")
    /// - one kind, several times: 3-digit groups = grouping ("10.000.000" -
    ///   Vietnamese dot-grouping is how every ybox amount arrives), or the
    ///   Indian pattern of 2-digit middles with a 3-digit tail ("1,00,000")
    /// - one kind, once: 1-2 digits after = decimal ("22,90", "10.50"),
    ///   exactly 3 = grouping ("20,000", "1.000" - nobody writes a prize to
    ///   three decimal places), more = malformed
    ///
    /// Anything else is nil, never a guess - this is where price-parser
    /// guesses for scraper convenience, and where a ranking must not.
    private static func parseAmount(_ digits: String) -> Double? {
        // A leading zero on a multi-digit integer is not how money is
        // written: "000" is the orphaned tail of spaced grouping ("150 000 ₽")
        // and "007" is an identifier. "$0" and "$0.50" stay valid.
        if digits.count > 1, digits.first == "0",
           let second = digits.dropFirst().first, second.isNumber {
            return nil
        }
        let hasComma = digits.contains(",")
        let hasDot = digits.contains(".")

        if hasComma, hasDot {
            guard let lastSeparator = digits.lastIndex(where: { $0 == "." || $0 == "," })
            else { return nil }
            let decimalMark = digits[lastSeparator]
            let groupingMark: Character = decimalMark == "." ? "," : "."
            let integerPart = String(digits[..<lastSeparator])
            let fractionPart = String(digits[digits.index(after: lastSeparator)...])
            guard (1...2).contains(fractionPart.count),
                  fractionPart.allSatisfy(\.isNumber),
                  !integerPart.contains(decimalMark),
                  let integer = parseGrouped(integerPart, separator: groupingMark)
            else { return nil }
            return integer + (Double(fractionPart) ?? 0) / pow(10, Double(fractionPart.count))
        }

        if hasComma || hasDot {
            let separator: Character = hasComma ? "," : "."
            let groups = digits.split(separator: separator, omittingEmptySubsequences: false)
                .map(String.init)
            guard groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
            else { return nil }
            if groups.count == 2 {
                let fraction = groups[1]
                switch fraction.count {
                case 1...2:
                    return Double(digits.replacingOccurrences(of: ",", with: "."))
                case 3:
                    return parseGrouped(digits, separator: separator)
                default:
                    return nil
                }
            }
            return parseGrouped(digits, separator: separator)
        }

        return Double(digits)
    }

    /// Valid grouped integer: a 1-3 digit head, then all-3-digit groups, or
    /// the Indian shape - 2-digit middles closing on a 3-digit tail.
    private static func parseGrouped(_ digits: String, separator: Character) -> Double? {
        let groups = digits.split(separator: separator, omittingEmptySubsequences: false)
            .map(String.init)
        guard let head = groups.first, (1...3).contains(head.count),
              groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else { return nil }
        let rest = groups.dropFirst()
        if rest.isEmpty { return Double(digits) }
        let western = rest.allSatisfy { $0.count == 3 }
        let indian = rest.dropLast().allSatisfy { $0.count == 2 } && rest.last?.count == 3
        guard western || indian else { return nil }
        return Double(groups.joined())
    }

    private static func attachedMarker(_ glue: String) -> String? {
        let candidate = glue.uppercased()
        for (symbol, code) in attachedMarkers where candidate == symbol {
            return code
        }
        return nil
    }

    /// Glue on the number itself: a symbol ("$", "NZ$") or a code
    /// ("50,000,000KRW").
    private static func gluedMarker(_ glue: String) -> String? {
        attachedMarker(glue) ?? wordMarkers[glue.lowercased()]
    }

    /// A whole neighboring word as a currency marker: a code or currency word
    /// ("USD", "đồng"), or a bare symbol standing alone ("₹ 10,000").
    private static func markerWord(_ word: String) -> String? {
        let normalized = normalizedWord(word)
        return wordMarkers[normalized] ?? attachedMarker(normalized)
    }

    // MARK: Context guards

    /// A fee word within three words of the token, either side, discards it:
    /// "$20 entry fee" and "Registration: $50" are costs, not prizes.
    private static func isNearFee(_ index: Int, in words: [String]) -> Bool {
        let window = max(0, index - 3)...min(words.count - 1, index + 3)
        for at in window {
            let word = normalizedWord(words[at])
            if feeWords.contains(word) { return true }
            if at + 1 <= window.upperBound,
               feePairs.contains(where: {
                   $0.0 == word && $0.1 == normalizedWord(words[at + 1])
               }) {
                return true
            }
        }
        return false
    }

    /// A pool word within five words BEFORE the token routes it to the pool:
    /// "Total prize pool $50,000", and "Tổng Giải Thưởng Lên Tới [amount]"
    /// where four words separate `tổng` from the number. Before only - a
    /// symmetric window would let a totals line claim the first-place amount
    /// sitting directly above it in a tiered list.
    private static func isPool(_ index: Int, in words: [String]) -> Bool {
        let before = max(0, index - 5)..<index
        if before.contains(where: { poolWords.contains(normalizedWord(words[$0])) }) {
            return true
        }
        let after = (index + 1)..<min(words.count, index + 3)
        return after.contains { poolWordsAfter.contains(normalizedWord(words[$0])) }
    }

    /// A valuation word within two words BEFORE the token: "(Worth $99)",
    /// "trị giá 500.000 VNĐ" pricing a gift, not a prize.
    private static func isValuation(_ index: Int, in words: [String]) -> Bool {
        let window = max(0, index - 2)..<index
        for at in window {
            let word = normalizedWord(words[at])
            if valuationWords.contains(word) { return true }
            if at + 1 < index,
               valuationPairs.contains(where: {
                   $0.0 == word && $0.1 == normalizedWord(words[at + 1])
               }) {
                return true
            }
        }
        return false
    }

    private static func namesNonCash(_ words: [String]) -> Bool {
        words.contains { nonCashWords.contains(normalizedWord($0)) }
    }

    /// Lowercased with surrounding punctuation stripped - `(Miễn` and `Tổng`
    /// compare as words, `pool:` matches `pool`.
    private static func normalizedWord(_ word: String) -> String {
        trimPunctuation(word).lowercased()
    }

    private static func trimPunctuation(_ word: String) -> String {
        var trimmed = word[...]
        while let first = trimmed.first, isTrimmable(first) { trimmed.removeFirst() }
        while let last = trimmed.last, isTrimmable(last) { trimmed.removeLast() }
        return String(trimmed)
    }

    /// Brackets, quotes and clause punctuation - never a currency symbol.
    /// `.` and `,` at a word's EDGE are sentence punctuation ("$300," in a
    /// tiered list, ".xyz"); inside a word they are the number's own
    /// separators and survive because trimming only eats the ends. `Rs.20,000`
    /// keeps its dot - it sits between letters and digits, not at an edge.
    private static func isTrimmable(_ character: Character) -> Bool {
        switch character {
        case "(", ")", "[", "]", "{", "}", "\"", "'", "“", "”", "‘", "’",
             ":", ";", "!", "?", "*", "-", "–", "+", ".", ",", "/", "…":
            return true
        default:
            return false
        }
    }
}

extension Competition {
    /// The comparable value, derived on read and memoized - NEVER persisted,
    /// so improving the normalizer never needs a schema migration and a store
    /// rebuild loses nothing. See COMP-5's design constraints.
    public var prizeValue: PrizeValue {
        PrizeNormalizer.cachedValue(prize: prize, title: title)
    }

    /// Comparator target for prize sorting: rankable USD, with valueless rows
    /// sunk below every priced one.
    public var prizeUSDForSort: Double {
        prizeValue.rankUSD ?? -.infinity
    }
}
