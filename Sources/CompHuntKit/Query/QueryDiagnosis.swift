import Foundation

/// One removable constraint of a query.
///
/// Only things that FILTER appear here. Bare terms are absent by construction:
/// they rank and never exclude, so removing one can never reveal a row and
/// offering it would be a suggestion that does nothing.
public enum QueryAxis: Equatable, Sendable {
    case category(CompetitionCategory)
    case region(Region)
    case source(SourceID)
    case deadline
    case phrase(String)

    /// How this reads in a sentence shown to a person.
    public var label: String {
        switch self {
        case .category(let category): category.displayName
        case .region(let region): region.displayName
        case .source(let source): source.displayName
        case .deadline: "the deadline window"
        case .phrase(let phrase): "\u{201C}\(phrase)\u{201D}"
        }
    }

    /// The operator that expresses it, so a removal can be applied to the
    /// query TEXT rather than to a parsed value that would then have to be
    /// serialized back and could disagree with what is on screen.
    public var token: String? {
        switch self {
        case .category(let category): "category:\(category.rawValue)"
        case .region(let region): "region:\(region.rawValue)"
        case .source(let source): "source:\(source.rawValue)"
        case .deadline: nil
        case .phrase: nil
        }
    }
}

/// The single constraint costing the most results, and what dropping it reveals.
public struct QueryDiagnosis: Equatable, Sendable {
    public let axis: QueryAxis
    /// How many competitions appear once this one constraint is removed.
    public let countWithout: Int

    public init(axis: QueryAxis, countWithout: Int) {
        self.axis = axis
        self.countWithout = countWithout
    }
}

public extension SearchQuery {
    /// Every constraint currently narrowing the list.
    var activeAxes: [QueryAxis] {
        // Fixed taxonomy order rather than Set order, so the same query always
        // diagnoses the same way.
        var axes = CompetitionCategory.allCases.filter(categories.contains).map(QueryAxis.category)
        axes += Region.allCases.filter(regions.contains).map(QueryAxis.region)
        axes += SourceID.allCases.filter(sources.contains).map(QueryAxis.source)
        if withinDays != nil { axes.append(.deadline) }
        axes += phrases.map(QueryAxis.phrase)
        return axes
    }

    mutating func remove(_ axis: QueryAxis) {
        switch axis {
        case .category(let category): categories.remove(category)
        case .region(let region): regions.remove(region)
        case .source(let source): sources.remove(source)
        case .deadline: withinDays = nil
        case .phrase(let phrase): phrases.removeAll { $0 == phrase }
        }
    }

    /// Competitions this query currently shows.
    ///
    /// Routed through `results` rather than re-deriving the rule, because a
    /// diagnosis that counts rows one way while the list renders them another
    /// is exactly how a suggestion ends up promising results that never appear.
    /// The tie-break is irrelevant to a count.
    func matchCount(in competitions: [Competition], now: Date = .now) -> Int {
        results(from: competitions, now: now, tieBreak: { _, _ in true }).items.count
    }

    /// The one constraint whose removal would reveal the most competitions, or
    /// nil when no single removal would help.
    ///
    /// Worth more now than it used to be. An empty list can no longer be caused
    /// by typing, so reaching one always means a deliberate operator or a quoted
    /// phrase - exactly the case where naming the expensive constraint pays,
    /// and the counts no longer include rows that only matched by accident.
    ///
    /// Deliberately reports ONE axis, not a ranked list. The goal is a single
    /// obvious click, and a menu of options is the same dead end with more
    /// reading.
    func narrowestConstraint(
        in competitions: [Competition], now: Date = .now
    ) -> QueryDiagnosis? {
        // Only a list with nothing in it is a dead end. Suggesting a removal
        // while results are on screen would be nagging about a filter that is
        // not costing anything.
        guard matchCount(in: competitions, now: now) == 0 else { return nil }
        var best: QueryDiagnosis?
        for axis in activeAxes {
            var relaxed = self
            relaxed.remove(axis)
            let count = relaxed.matchCount(in: competitions, now: now)
            // Only worth mentioning if it actually reveals something.
            guard count > 0 else { continue }
            if best == nil || count > best!.countWithout {
                best = QueryDiagnosis(axis: axis, countWithout: count)
            }
        }
        return best
    }
}
