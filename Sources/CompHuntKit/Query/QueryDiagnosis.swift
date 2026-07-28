import Foundation

/// One removable piece of a query. Mirrors what the chips show, so anything
/// the person can see they can also be told about.
public enum QueryAxis: Equatable, Sendable {
    case category(CompetitionCategory)
    case region(Region)
    case deadline
    case term(String)

    /// How this reads in a sentence shown to a person.
    public var label: String {
        switch self {
        case .category(let category): category.displayName
        case .region(let region): region.displayName
        case .deadline: "the date range"
        case .term(let term): "\u{201C}\(term)\u{201D}"
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

public extension CompetitionQuery {
    /// Every constraint currently narrowing the list, in the order the chips
    /// render them.
    var activeAxes: [QueryAxis] {
        var axes = CompetitionCategory.allCases
            .filter(categories.contains)
            .map(QueryAxis.category)
        if let region { axes.append(.region(region)) }
        if deadlineAfter != nil || deadlineBefore != nil { axes.append(.deadline) }
        axes += terms.map(QueryAxis.term)
        return axes
    }

    mutating func remove(_ axis: QueryAxis) {
        switch axis {
        case .category(let category): categories.remove(category)
        case .region: region = nil
        case .deadline:
            deadlineAfter = nil
            deadlineBefore = nil
        case .term(let term): terms.removeAll { $0 == term }
        }
    }

    /// Competitions this query currently shows.
    func matchCount(in competitions: [Competition], now: Date = .now) -> Int {
        competitions.filter { $0.isCurrent(asOf: now) && matches($0) }.count
    }

    /// The one constraint whose removal would reveal the most competitions, or
    /// nil when no single removal would help.
    ///
    /// Exists because "Nothing matches this filter" is a dead end. A generated
    /// query can carry four constraints at once, and a person has no way to
    /// know which of them is the expensive one - a category holding a single
    /// current competition looks exactly like a category holding forty. The app
    /// can measure that in a few hundred comparisons, so it should say which
    /// chip to remove rather than leaving it to be guessed.
    ///
    /// Deliberately reports ONE axis, not a ranked list. The goal is a single
    /// obvious click, and a menu of options is the same dead end with more
    /// reading.
    func narrowestConstraint(
        in competitions: [Competition], now: Date = .now
    ) -> QueryDiagnosis? {
        let current = matchCount(in: competitions, now: now)
        var best: QueryDiagnosis?
        for axis in activeAxes {
            var relaxed = self
            relaxed.remove(axis)
            let count = relaxed.matchCount(in: competitions, now: now)
            // Only worth mentioning if it actually reveals something.
            guard count > current else { continue }
            if best == nil || count > best!.countWithout {
                best = QueryDiagnosis(axis: axis, countWithout: count)
            }
        }
        return best
    }
}
