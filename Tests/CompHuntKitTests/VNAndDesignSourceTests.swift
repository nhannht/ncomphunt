import Foundation
import Testing
@testable import CompHuntKit

@Suite struct YboxParsing {
    private func html() throws -> String {
        try #require(String(data: try fixture("ybox", "html"), encoding: .utf8))
    }

    /// Fixture deadlines are Jul/Aug/Nov 2026, so pin "now" before them.
    private let now = ISO8601DateFormatter().date(from: "2026-07-10T00:00:00Z")!

    @Test func parsesEmbeddedState() throws {
        let dtos = try YboxSource.parse(html: try html(), now: now)
        #expect(dtos.count == 3)

        let first = try #require(dtos.first)
        #expect(first.source == "ybox")
        #expect(first.title.contains("Go Big Or Go USA"))
        #expect(first.url.hasPrefix("https://ybox.vn/cuoc-thi/"))
        #expect(first.registrationDeadline != nil)
    }

    @Test func vietnameseRegionAndCategory() throws {
        let dtos = try YboxSource.parse(html: try html(), now: now)
        for dto in dtos {
            #expect(Classifier.region(for: dto) == .vietnam)
        }
        let boardGame = try #require(dtos.first { $0.title.contains("Board Game") })
        #expect(Classifier.category(for: boardGame) == .design)
    }

    @Test func pastDeadlinesAreDropped() throws {
        let farFuture = ISO8601DateFormatter().date(from: "2030-01-01T00:00:00Z")!
        let dtos = try YboxSource.parse(html: try html(), now: farFuture)
        #expect(dtos.isEmpty)
    }

    @Test func missingStateThrowsSkip() {
        #expect(throws: SourceSkipped.self) {
            _ = try YboxSource.parse(html: "<html><body>nothing here</body></html>")
        }
    }

    @Test func braceScannerHandlesBracesInStrings() throws {
        let html = #"<script>window.__INITIAL_STATE__ = {"app": {"initialPosts": {"g": {"edges": [{"_id": "x1", "title": "T }; tricky", "deadline": "2099-01-01T00:00:00.000Z", "community": {"url": "cuoc-thi"}}]}}}};</script>"#
        let dtos = try YboxSource.parse(html: html)
        #expect(dtos.count == 1)
        #expect(dtos[0].title == "T }; tricky")
    }

    /// Member essays, results posts, and resurfaced 2017-era posts carry no
    /// deadline; moderated contest announcements always do.
    @Test func deadlinelessJunkIsDropped() throws {
        let html = #"""
        <script>window.__INITIAL_STATE__ = {"app": {"initialPosts": {
          "NewestPosts": {"edges": [
            {"_id": "essay1", "title": "TRẺ SỚM HƠN NGƯỜI KHÁC MỘT VÀI NĂM CÓ LÀ MAY MẮN?",
             "community": {"url": "cuoc-thi"}},
            {"_id": "real1", "title": "[Online] Cuộc Thi Thật 2099",
             "deadline": "2099-06-01T16:59:59.000Z", "community": {"url": "cuoc-thi"}}
          ]},
          "RecommendedPost30": {"edges": [
            {"_id": "zombie1", "title": "Cuộc Thi Viết Cũ 2017", "community": {"url": "cuoc-thi"}}
          ]}
        }}};</script>
        """#
        let dtos = try YboxSource.parse(html: html)
        #expect(dtos.count == 1)
        #expect(dtos[0].title == "[Online] Cuộc Thi Thật 2099")
    }

    /// The same post often appears in a curated rail (full copy) and a
    /// recommendation rail (slim copy, no deadline). The curated copy must win
    /// regardless of dictionary ordering, and the slim copy must not block it.
    @Test func curatedRailBeatsSlimRecommendationCopy() throws {
        let html = #"""
        <script>window.__INITIAL_STATE__ = {"app": {"initialPosts": {
          "RecommendedPost15": {"edges": [
            {"_id": "dup1", "title": "[Online] Cuộc Thi Trùng", "community": {"url": "cuoc-thi"}}
          ]},
          "NewestPosts": {"edges": [
            {"_id": "dup1", "title": "[Online] Cuộc Thi Trùng",
             "deadline": "2099-03-01T16:59:59.000Z", "community": {"url": "cuoc-thi"}}
          ]}
        }}};</script>
        """#
        let dtos = try YboxSource.parse(html: html)
        #expect(dtos.count == 1)
        #expect(dtos[0].registrationDeadline != nil)
    }
}

@Suite struct ContestWatchersParsing {
    @Test func parsesFeedItems() throws {
        let dtos = ContestWatchersSource.parse(try fixture("contestwatchers", "xml"))
        #expect(dtos.count == 3)

        let first = try #require(dtos.first)
        #expect(first.source == "contestwatchers")
        #expect(first.title == "Kokuyo Design Award 2027: Dialogue")
        #expect(first.url.hasPrefix("https://www.contestwatchers.com/"))
        #expect(first.tags.contains("creative"))
        #expect(!first.details.contains("<"))
    }

    @Test func decodesEntityInTitle() throws {
        let dtos = ContestWatchersSource.parse(try fixture("contestwatchers", "xml"))
        let hiii = try #require(dtos.first { $0.title.contains("Hiiibrand") })
        #expect(hiii.title.contains("Brand & Communication Design"))
    }

    @Test func classifiesAsDesign() throws {
        let dtos = ContestWatchersSource.parse(try fixture("contestwatchers", "xml"))
        for dto in dtos {
            #expect(Classifier.category(for: dto) == .design)
        }
    }

    @Test func channelMetadataIsNotAnItem() throws {
        let dtos = ContestWatchersSource.parse(try fixture("contestwatchers", "xml"))
        #expect(!dtos.contains { $0.title == "Contest Watchers" })
    }
}
