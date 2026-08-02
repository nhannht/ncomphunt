import Foundation
import Testing
@testable import CompHuntKit

private func dto(
    title: String = "Some Contest",
    url: String = "https://example.com/contest",
    category: CompetitionCategory? = nil,
    location: String = "",
    organizer: String = "",
    tags: [String] = []
) -> CompetitionDTO {
    CompetitionDTO(
        source: "test", title: title, organizer: organizer, url: url,
        category: category, location: location, tags: tags
    )
}

@Suite struct CategoryClassification {
    @Test func explicitCategoryWins() {
        let d = dto(title: "Design Jam", url: "https://kaggle.com/x", category: .ctf)
        #expect(Classifier.category(for: d) == .ctf)
    }

    @Test func hostMapping() {
        #expect(Classifier.category(for: dto(url: "https://codeforces.com/contests/1234")) == .cp)
        #expect(Classifier.category(for: dto(url: "https://www.kaggle.com/competitions/arc")) == .ai)
        #expect(Classifier.category(for: dto(url: "https://atcoder.jp/contests/abc420")) == .cp)
    }

    @Test func resourceTagMapping() {
        let d = dto(url: "https://clist.by/standings/x", tags: ["leetcode.com"])
        #expect(Classifier.category(for: d) == .cp)
    }

    @Test func titleKeywords() {
        #expect(Classifier.category(for: dto(title: "picoCTF 2026")) == .ctf)
        #expect(Classifier.category(for: dto(title: "Zalo AI Challenge")) == .ai)
        #expect(Classifier.category(for: dto(title: "National Logo Design Award")) == .design)
        #expect(Classifier.category(for: dto(title: "Spring Hackathon 2026")) == .hackathon)
    }

    @Test func themeTags() {
        let d = dto(title: "XPRIZE", tags: ["Machine Learning/AI", "Education"])
        #expect(Classifier.category(for: d) == .ai)
    }

    @Test func fallbackIsOther() {
        #expect(Classifier.category(for: dto(title: "Spelling Bee Championship")) == .other)
    }
}

@Suite struct RegionClassification {
    @Test func vnTopLevelDomain() {
        #expect(Classifier.region(for: dto(url: "https://ybox.vn/cuoc-thi/abc")) == .vietnam)
    }

    @Test func diacriticCity() {
        #expect(Classifier.region(for: dto(location: "Hà Nội")) == .vietnam)
        #expect(Classifier.region(for: dto(location: "TP. Hồ Chí Minh")) == .vietnam)
    }

    @Test func plainSpelling() {
        #expect(Classifier.region(for: dto(location: "Ho Chi Minh City, Vietnam")) == .vietnam)
        #expect(Classifier.region(for: dto(title: "Da Nang Hackathon")) == .vietnam)
    }

    /// VN technical contests arrive from the global aggregators under a non-.vn
    /// host and an English title; the contest-brand allowlist tags them vietnam.
    @Test func contestBrands() {
        #expect(Classifier.region(for: dto(title: "VNOI Cup 2026", url: "https://clist.by/x")) == .vietnam)
        #expect(Classifier.region(for: dto(title: "WhiteHat Contest 2026", url: "https://ctftime.org/event/1")) == .vietnam)
        #expect(Classifier.region(for: dto(title: "Zalo AI Challenge", url: "https://www.kaggle.com/z")) == .vietnam)
        #expect(Classifier.region(for: dto(title: "SVATTT Qualifier", url: "https://ctftime.org/event/2")) == .vietnam)
        #expect(Classifier.region(for: dto(title: "Some CTF", url: "https://ctftime.org/event/3", organizer: "Efiens")) == .vietnam)
    }

    /// The brand tokens must not leak: a spaced "white hat" is not the VN
    /// WhiteHat brand, and unrelated global contests stay global.
    @Test func brandTokensDoNotLeakToGlobal() {
        #expect(Classifier.region(for: dto(title: "White Hat Security Summit", url: "https://example.com/x")) == .global)
        #expect(Classifier.region(for: dto(title: "Google Hash Code", url: "https://codingcompetitions.withgoogle.com/x")) == .global)
    }

    @Test func globalByDefault() {
        #expect(Classifier.region(for: dto(location: "Berlin, Germany")) == .global)
        #expect(Classifier.region(for: dto(location: "Online")) == .global)
    }
}

@Suite struct DedupeKey {
    @Test func stripsQueryAndTrailingSlashAndCase() {
        let d = dto(url: "https://Example.com/Contest/?utm_source=x&ref=1")
        #expect(d.key == "https://example.com/contest")
    }

    @Test func emptyURLFallsBackToIdentity() {
        let d = CompetitionDTO(source: "src", title: "Title", organizer: "Org", url: "")
        #expect(d.key == "src:org:title")
    }
}

// MARK: - The widened taxonomy and multi-tagging
//
// Every title below is a REAL row from the live store, measured 2026-08-02.
// Full method and numbers in `research/comp-27-classification/`.

@Suite struct WordAnchoredMatching {
    /// The bug this anchoring exists to close. `impactforge` contains the
    /// letters c-t-f mid-word (impa-CTF-orge), and the classifier filed this
    /// Devpost project as a security CTF in the shipped store.
    @Test func aWordMerelyContainingCTFIsNotACTF() {
        #expect(Classifier.category(for: dto(title: "ImpactForge")) != .ctf)
    }

    /// The other side of the same rule: CTF events are named `<name>CTF`, so a
    /// strict whole-word match would lose every one of them.
    @Test func aNameEndingInCTFStillIs() {
        for name in ["picoCTF 2026", "BrunnerCTF 2026", "jailCTF", "DownUnderCTF 2026"] {
            #expect(Classifier.category(for: dto(title: name)) == .ctf, "\(name)")
        }
    }

    /// Punctuation is flattened on both sides, so a slash cannot hide a word.
    @Test func punctuationDoesNotBreakAMatch() {
        #expect(Classifier.category(for: dto(title: "UI/UX Challenge")) == .design)
    }

    /// Titles glue the year straight onto the name as often as they space it.
    /// Normalisation splits the letter-digit seam, so both spellings anchor -
    /// and it fixes every needle on both sides at once, category and region.
    @Test func aYearGluedToTheNameStillAnchors() {
        #expect(Classifier.category(for: dto(title: "picoCTF2024")) == .ctf)
        #expect(Classifier.category(for: dto(title: "Hackathon2026")) == .hackathon)
        #expect(Classifier.region(for: dto(title: "VNOI2024", url: "https://clist.by/x")) == .vietnam)
    }
}

@Suite struct VietnameseCategories {
    @Test func theVietnameseLaneClassifies() {
        let cases: [(String, CompetitionCategory)] = [
            ("Cuộc Thi Viết \"Ấn Ký\"", .writing),
            ("Cuộc Thi Nhiếp Ảnh Nghệ Thuật Xiếc Việt Nam", .media),
            ("Cuộc Thi Phim Ngắn Hiền Tài Hôm Nay", .media),
            ("Cuộc Thi Khởi Nghiệp Xanh", .business),
            ("Cuộc Thi Hùng Biện Tiếng Nhật Quốc Tế", .academic),
            ("Cuộc Thi Vẽ Tranh Digital", .design),
        ]
        for (title, want) in cases {
            #expect(Classifier.category(for: dto(title: title)) == want, "\(title)")
        }
    }

    /// A prize and an organiser are not what the competition IS. Both produced
    /// false positives when measured: this row is a writing contest run by a
    /// business association, and `hoc bong` (scholarship) names a prize.
    ///
    /// The organiser is carried in the TITLE here on purpose. Category reads
    /// title and tags only, so putting the association in `dto.organizer` would
    /// assert nothing - the field is never on the category path, and the test
    /// passed no matter which needles the business list held.
    @Test func aPrizeOrAnOrganiserIsNotTheKind() {
        let association = dto(
            title: "Cuộc Thi Viết \"Hàng Việt Trong Mắt Người Trẻ\" "
                + "- Hiệp Hội Doanh Nghiệp Hàng Việt Nam Chất Lượng Cao")
        #expect(Classifier.tags(for: association) == [.writing])

        let scholarship = dto(title: "Cuộc Thi Viết Về Học Bổng Toàn Phần")
        #expect(Classifier.tags(for: scholarship) == [.writing])
    }

    /// A Vietnamese syllable is not a word. The language writes a compound as
    /// separate syllables, so a bare needle matches every unrelated compound
    /// that happens to contain it - `thơ` (poem) inside `tuổi thơ` (childhood)
    /// filed a robotics contest as poetry, on a live row.
    @Test func aSyllableInsideAnUnrelatedCompoundIsNotAMatch() {
        #expect(!Classifier.tags(for: dto(title: "Cuộc Thi Robot Dành Cho Tuổi Thơ")).contains(.writing))
        #expect(!Classifier.tags(for: dto(title: "Giải Thưởng Người Có Sức Ảnh Hưởng")).contains(.media))
        #expect(Classifier.tags(for: dto(title: "Cuộc Thi Hùng Biện Song Ngữ")) == [.academic])
    }

    /// The other side of that rule: the compounds that really do name the
    /// activity still carry every case the bare syllables used to.
    @Test func theCompoundThatNamesTheActivityStillMatches() {
        let cases: [(String, CompetitionCategory)] = [
            ("Cuộc Thi Sáng Tác Thơ Thiếu Nhi", .writing),
            ("Cuộc Thi Bộ Ảnh Đẹp Mùa Hè", .media),
            ("Cuộc Thi Sáng Tác Ca Khúc Về Quê Hương", .media),
        ]
        for (title, want) in cases {
            #expect(Classifier.category(for: dto(title: title)) == want, "\(title)")
        }
    }
}

@Suite struct MultiTagging {
    /// The row that proves a single category is the wrong shape. There is no
    /// correct one-word answer for a contest that is all three at once.
    @Test func aContestCanBeSeveralThingsAtOnce() {
        let d = dto(title: "Cuộc Thi Sáng Tác Thơ, Âm Nhạc, Nhiếp Ảnh")
        let tags = Classifier.tags(for: d)
        #expect(tags.contains(.writing))
        #expect(tags.contains(.media))
    }

    /// A declaring source ends the search. Never spend a guess on a row that
    /// CTFtime already answered - measurement showed the model disagreeing with
    /// those declarations about half the time.
    @Test func aDeclaringSourceReturnsOneTagAndStops() {
        let d = dto(title: "Design Photography Writing Startup", url: "https://ctftime.org/event/1")
        #expect(Classifier.tags(for: d) == [.ctf])
    }

    @Test func nothingMatchingYieldsNoTagsAndReadsAsOther() {
        let d = dto(title: "Cuộc Thi Dành Cho Đầu Bếp Trẻ - Rising Chefs Challenge")
        #expect(Classifier.tags(for: d).isEmpty)
        #expect(Classifier.category(for: d) == .other)
    }
}
