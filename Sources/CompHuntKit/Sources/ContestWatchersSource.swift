import Foundation

/// Contest Watchers (contestwatchers.com): international creative and design
/// competition directory, consumed via its WordPress RSS feed.
public struct ContestWatchersSource: CompetitionSource {
    public let name = "contestwatchers"

    public init() {}

    public func fetch() async throws -> [CompetitionDTO] {
        let url = URL(string: "https://www.contestwatchers.com/feed/")!
        let data = try await HTTP.get(url)
        return Self.parse(data)
    }

    static func parse(_ data: Data) -> [CompetitionDTO] {
        let collector = RSSItemCollector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.parse()
        return collector.items
            .filter { !$0.title.isEmpty && !$0.link.isEmpty }
            .map { item in
                CompetitionDTO(
                    source: "contestwatchers",
                    title: Text.decodeEntities(item.title),
                    url: item.link,
                    details: Text.plain(item.itemDescription),
                    // "creative" routes plain entries to .design in the
                    // classifier; stronger category tags still win.
                    tags: item.categories + ["creative"]
                )
            }
    }
}

/// Minimal RSS 2.0 item collector. Channel-level title/link elements are
/// ignored because collection only happens inside an open <item>.
final class RSSItemCollector: NSObject, XMLParserDelegate {
    struct Item {
        var title = ""
        var link = ""
        var categories: [String] = []
        var itemDescription = ""
    }

    private(set) var items: [Item] = []
    private var current: Item?
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "item" {
            current = Item()
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard current != nil else { return }
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title": current?.title = text
        case "link": current?.link = text
        case "category": current?.categories.append(text)
        case "description": current?.itemDescription = text
        case "item":
            if let item = current { items.append(item) }
            current = nil
        default: break
        }
        buffer = ""
    }
}
