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
