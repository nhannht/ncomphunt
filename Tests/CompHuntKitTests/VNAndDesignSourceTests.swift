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
        let html = #"<script>window.__INITIAL_STATE__ = {"app": {"initialPosts": {"g": {"edges": [{"_id": "x1", "title": "T }; tricky", "community": {"url": "cuoc-thi"}}]}}}};</script>"#
        let dtos = try YboxSource.parse(html: html)
        #expect(dtos.count == 1)
        #expect(dtos[0].title == "T }; tricky")
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
