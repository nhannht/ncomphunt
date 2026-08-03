import Foundation
import Testing
@testable import CompHuntKit

/// FX rates are approximate and pinned in `PrizeNormalizer.usdRates`
/// (2026-08), so expectations here are exact products of those constants.
private func approx(_ value: Double?, _ expected: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 0.01
}

@Suite struct SingleAmounts {
    @Test func plainDollarAmounts() {
        #expect(approx(PrizeNormalizer.normalize("$4,000").topPrizeUSD, 4000))
        #expect(approx(PrizeNormalizer.normalize("$45,000").topPrizeUSD, 45000))
    }

    /// Devpost serves `$0` on free hackathons. Zero is a real answer - "no
    /// cash prize" - and must not be confused with "could not parse".
    @Test func zeroIsAnAnswerNotAFailure() {
        let value = PrizeNormalizer.normalize("$0")
        #expect(value.topPrizeUSD == 0)
        #expect(value.hasSignal)
    }

    /// CTFtime money arrives suffix-form as often as prefix-form.
    @Test func suffixDollar() {
        #expect(approx(PrizeNormalizer.normalize("Top 1: 670$").topPrizeUSD, 670))
    }

    @Test func codeBeforeAndAfter() {
        #expect(approx(PrizeNormalizer.normalize("USD 10,000").topPrizeUSD, 10000))
        #expect(approx(PrizeNormalizer.normalize("500 USD").topPrizeUSD, 500))
    }

    @Test func nonDollarSymbols() {
        #expect(approx(PrizeNormalizer.normalize("£10,000").topPrizeUSD, 12800))
        #expect(approx(PrizeNormalizer.normalize("₹ 10,000").topPrizeUSD, 115))
        #expect(approx(PrizeNormalizer.normalize("Rs.20,000").topPrizeUSD, 230))
        #expect(approx(PrizeNormalizer.normalize("22,90 €").topPrizeUSD, 24.732))
    }

    /// `NZ$` must resolve before `$` can claim the number as USD.
    @Test func longestSymbolWins() {
        #expect(approx(PrizeNormalizer.normalize("1st place: NZ$400").topPrizeUSD, 240))
    }
}

@Suite struct ScaleWords {
    @Test func attachedScales() {
        #expect(approx(PrizeNormalizer.normalize("$5k").topPrizeUSD, 5000))
        #expect(approx(PrizeNormalizer.normalize("SGD 5k").topPrizeUSD, 3750))
        #expect(approx(PrizeNormalizer.normalize("1.5M USD").topPrizeUSD, 1_500_000))
    }

    @Test func englishScaleWords() {
        #expect(approx(PrizeNormalizer.normalize("$2 million").topPrizeUSD, 2_000_000))
        #expect(approx(PrizeNormalizer.normalize("$10 thousand").topPrizeUSD, 10000))
    }

    /// The Vietnamese scales, with and without diacritics. A scale word alone
    /// never creates a token - the marker is still required - which is what
    /// makes bare `ty`/`ti` safe to list.
    @Test func vietnameseScaleWords() {
        #expect(approx(PrizeNormalizer.normalize("50 triệu VNĐ").topPrizeUSD, 1950))
        #expect(approx(PrizeNormalizer.normalize("50 trieu VND").topPrizeUSD, 1950))
        #expect(approx(PrizeNormalizer.normalize("1.8 tỷ VND").topPrizeUSD, 70200))
        #expect(approx(PrizeNormalizer.normalize("2 ty VND").topPrizeUSD, 78000))
    }

    @Test func indianScaleWords() {
        #expect(approx(PrizeNormalizer.normalize("Rs 1 lakh").topPrizeUSD, 1150))
        #expect(approx(PrizeNormalizer.normalize("INR 2 crore").topPrizeUSD, 230_000))
    }
}

@Suite struct SeparatorDisambiguation {
    /// Vietnamese dot-grouping: how every ybox amount arrives.
    @Test func dotGrouping() {
        #expect(approx(PrizeNormalizer.normalize("10.000.000 VNĐ").topPrizeUSD, 390))
        #expect(approx(PrizeNormalizer.normalize("200.000 Đồng").topPrizeUSD, 7.8))
    }

    @Test func commaGrouping() {
        #expect(approx(PrizeNormalizer.normalize("$20,500").topPrizeUSD, 20500))
    }

    @Test func decimalForms() {
        #expect(approx(PrizeNormalizer.normalize("$10.50").topPrizeUSD, 10.5))
        #expect(approx(PrizeNormalizer.normalize("€1,23").topPrizeUSD, 1.3284))
    }

    @Test func mixedSeparators() {
        #expect(approx(PrizeNormalizer.normalize("$1,234.56").topPrizeUSD, 1234.56))
        #expect(approx(PrizeNormalizer.normalize("€1.234,56").topPrizeUSD, 1333.32))
    }

    /// The Indian grouping shape: 2-digit middles closing on a 3-digit tail.
    @Test func indianGrouping() {
        #expect(approx(PrizeNormalizer.normalize("₹1,00,000").topPrizeUSD, 1150))
    }

    /// Ambiguity resolves to nil, never to a guess - a wrong number silently
    /// corrupts the ranking, a nil just leaves the row unranked.
    @Test func malformedNumbersResolveToNothing() {
        #expect(PrizeNormalizer.normalize("$1.2345").hasSignal == false)
        #expect(PrizeNormalizer.normalize("$1,23,4").hasSignal == false)
        #expect(PrizeNormalizer.normalize("$12,3.4,5").hasSignal == false)
    }
}

@Suite struct TiersAndPools {
    /// A tiered list resolves to its first place: "what can I win" is the max
    /// single amount, not the sum.
    @Test func tieredListTakesTheMax() {
        let value = PrizeNormalizer.normalize(
            "1st Place - $300\n2nd Place - $200\n3rd Place - $100")
        #expect(approx(value.topPrizeUSD, 300))
        #expect(value.totalPoolUSD == nil)
    }

    @Test func slashSeparatedTiers() {
        #expect(approx(
            PrizeNormalizer.normalize("Prizes: $750 / $500 / $250 for the top three.").topPrizeUSD,
            750))
    }

    /// A pool keyword routes the amount to the secondary signal - a pool is
    /// not a single winnable prize.
    @Test func poolKeywordRoutesToPool() {
        let value = PrizeNormalizer.normalize("Total prize pool $50,000")
        #expect(value.topPrizeUSD == nil)
        #expect(approx(value.totalPoolUSD, 50000))
    }

    @Test func vietnamesePool() {
        let value = PrizeNormalizer.normalize("Tổng Giải Thưởng Lên Tới 1.800.000.000 VND")
        #expect(value.topPrizeUSD == nil)
        #expect(approx(value.totalPoolUSD, 70200))
    }

    /// "up to X" is a ceiling on a winnable amount, an ordinary top candidate.
    @Test func upToIsACeilingNotAPool() {
        #expect(approx(PrizeNormalizer.normalize("prizes up to Rs.20,000").topPrizeUSD, 230))
    }

    /// The OmniCTF monster from the live store: 30 lines mixing cash tiers,
    /// license bundles and domain prizes. Cash resolves to the finals top;
    /// the domain lines land in nonCash instead of being priced.
    @Test func theOmniCTFMonster() {
        let value = PrizeNormalizer.normalize("""
            FINALS PRIZES:

            Top 1: 670$
            Top 2: 420$
            Top 3: 210$

            QUALS PRIZES:

            12 Teams will qualify for the OmniCTF 2026 Finals.

            Top 3 Romanian Teams:
            1st: 7 .xyz domains
            2nd: 6 .xyz domains
            3rd: 3 .xyz domains

            BEST Writeups:
            1 month Caido + 1 .xyz domain + 1x kWAPTA for 3 teams
            """)
        #expect(approx(value.topPrizeUSD, 670))
        #expect(!value.nonCash.isEmpty)
    }
}

@Suite struct AdjacencyGuards {
    /// Numbers are everywhere in prize prose; money markers are not. A number
    /// no marker touches is someone else's number.
    @Test func bareNumbersAreNotMoney() {
        #expect(PrizeNormalizer.normalize("12 Teams will qualify for the Finals.").hasSignal == false)
        #expect(PrizeNormalizer.normalize("Prizes for the top 3 teams").hasSignal == false)
        #expect(PrizeNormalizer.normalize("2026 competition is CANCELLED!").hasSignal == false)
    }

    /// A model number is an identifier, not an amount: unrecognized glue on
    /// either side of the digits vetoes the token outright.
    @Test func identifiersWithDigitsAreNotMoney() {
        #expect(PrizeNormalizer.normalize(
            "Tai Nghe Bluetooth Sony WH-1000XM5").hasSignal == false)
    }

    /// An entry fee is a cost, not a prize.
    @Test func feesAreDiscarded() {
        #expect(PrizeNormalizer.normalize("$20 entry fee").hasSignal == false)
        #expect(PrizeNormalizer.normalize("Registration: $50").hasSignal == false)
        #expect(PrizeNormalizer.normalize("Lệ phí 100.000 VNĐ").hasSignal == false)
    }
}

@Suite struct TBAFamily {
    /// None of these are enumerated anywhere in the normalizer - they carry no
    /// money token, so they fall out as nothing by construction. That is the
    /// point: `TDB` is a typo nobody would think to list.
    @Test func placeholdersYieldNothing() {
        for raw in ["TBA", "TBD", "TDB", "[TBA]", "To be announced!",
                    "To Be Determined", "See event.", "See https://example.com/prizes",
                    "2026 competition is CANCELLED!",
                    "No monetary prizes. The prize is your own enjoyment."] {
            #expect(PrizeNormalizer.normalize(raw).hasSignal == false, "\(raw)")
        }
    }
}

@Suite struct NonCashPrizes {
    @Test func trophiesAndSwag() {
        let trophies = PrizeNormalizer.normalize(
            "Trophies are given to the top 3 teams (if US-based)")
        #expect(trophies.topPrizeUSD == nil)
        #expect(trophies.nonCash.count == 1)

        let mixed = PrizeNormalizer.normalize("$500\nWinner swag and stickers")
        #expect(approx(mixed.topPrizeUSD, 500))
        #expect(mixed.nonCash.count == 1)
    }
}

@Suite struct TitleFallback {
    /// ybox serves no prize field; the amount lives in the headline. 40% of
    /// the live store is unreachable without this path.
    @Test func yboxTitleYieldsAnInferredValue() {
        let value = PrizeNormalizer.value(
            prize: "",
            title: "[Toàn Quốc] Cơ Hội Nhận 10.000.000 VNĐ Từ Cuộc Thi "
                + "\"50 Năm Thành Phố\" Do Báo Tuổi Trẻ Tổ Chức 2026 (Miễn Phí Tham Dự)")
        #expect(approx(value.topPrizeUSD, 390))
        #expect(value.confidence == .inferred)
    }

    @Test func yboxPoolTitle() {
        let value = PrizeNormalizer.value(
            prize: "",
            title: "[Toàn Quốc] Cơ Hội Nhận Tổng Giải Thưởng Lên Tới "
                + "1.800.000.000 VND Tại Cuộc Thi \"The Banker\" (Miễn Phí Tham Dự)")
        #expect(value.topPrizeUSD == nil)
        #expect(approx(value.totalPoolUSD, 70200))
        #expect(value.confidence == .inferred)
    }

    /// "Miễn Phí Tham Dự" (free to enter) trails every ybox title; a fee
    /// guard that killed on bare `phí` would erase the whole lane.
    @Test func freeToEnterIsNotAFee() {
        let value = PrizeNormalizer.value(
            prize: "", title: "Cơ Hội Nhận 5.000.000 VNĐ (Miễn Phí Tham Dự)")
        #expect(approx(value.topPrizeUSD, 195))
    }

    /// A declared prize field always beats the title, even when smaller.
    @Test func declaredBeatsInferred() {
        let value = PrizeNormalizer.value(
            prize: "$500", title: "Cơ Hội Nhận 10.000.000 VNĐ")
        #expect(approx(value.topPrizeUSD, 500))
        #expect(value.confidence == .declared)
    }

    /// A title is not a prize list: the fallback keeps cash signal only.
    @Test func titleFallbackCollectsNoNonCash() {
        let value = PrizeNormalizer.value(
            prize: "", title: "Win a certificate and 1.000.000 VNĐ")
        #expect(approx(value.topPrizeUSD, 39))
        #expect(value.nonCash.isEmpty)
    }
}

@Suite struct Presentation {
    @Test func summaryLines() {
        #expect(PrizeNormalizer.normalize("$4,000").summaryLine == "≈ $4,000 top prize")
        #expect(PrizeNormalizer.normalize("Total prize pool $50,000").summaryLine
            == "≈ $50,000 pool")
        #expect(PrizeNormalizer.normalize("TBA").summaryLine == nil)
    }

    @Test func compactForm() {
        #expect(PrizeNormalizer.normalize("$4,000").compactUSD == "$4K")
        #expect(PrizeNormalizer.normalize("10.000.000 VNĐ").compactUSD == "$390")
    }
}

@Suite struct NeverThrows {
    /// Total on any input: the function extracts, it never validates.
    @Test func garbageYieldsEmptyValues() {
        for raw in ["", " ", "\n\n\n", "🏆🏆🏆", "$", "$$$", "...", ",,,",
                    "$999999999999999999", "﷽", String(repeating: "$1 ", count: 5000)] {
            _ = PrizeNormalizer.normalize(raw)
        }
        #expect(PrizeNormalizer.normalize("$999999999999999999").hasSignal == false)
    }
}

/// The whole live store, snapshotted 2026-08-03: every distinct prize string
/// (85, from 133 rows carrying one) and every ybox title (117). The counts are
/// pinned so any rule change that alters real-world coverage shows up as a
/// number moving, in either direction.
@Suite struct CorpusCoverage {
    private struct Corpus: Decodable {
        let prizes: [String]
        let yboxTitles: [String]
    }

    private func load() throws -> Corpus {
        let url = try #require(Bundle.module.url(
            forResource: "prize-corpus", withExtension: "json",
            subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
    }

    @Test func prizeFieldCoverage() throws {
        let corpus = try load()
        let values = corpus.prizes.map(PrizeNormalizer.normalize)
        let cash = values.filter { $0.rankUSD != nil }.count
        let nonCashOnly = values.filter { $0.rankUSD == nil && !$0.nonCash.isEmpty }.count
        let nothing = values.filter { !$0.hasSignal }.count
        print("corpus prizes: \(corpus.prizes.count) cash=\(cash) nonCashOnly=\(nonCashOnly) nothing=\(nothing)")
        #expect(corpus.prizes.count == 85)
        #expect(cash == 64)
        #expect(nonCashOnly == 4)
        #expect(nothing == 17)
    }

    @Test func yboxTitleCoverage() throws {
        let corpus = try load()
        let values = corpus.yboxTitles.map { PrizeNormalizer.value(prize: "", title: $0) }
        let cash = values.filter { $0.rankUSD != nil }.count
        print("corpus ybox titles: \(corpus.yboxTitles.count) cash=\(cash)")
        #expect(corpus.yboxTitles.count == 117)
        #expect(cash == 68)
    }
}
