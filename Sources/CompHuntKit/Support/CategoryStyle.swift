import SwiftUI

/// The one place category color and short-label decisions live.
///
/// The list rows, the chip row, the expanded view, and the widget all read
/// from here. Before this file the app and the widget each carried a private
/// mapping and they had drifted: CTF was purple in one and red in the other.
/// A mapping that exists once cannot disagree with itself.
public extension CompetitionCategory {
    /// The accent for the tiny dots and tinted labels that replaced the filled
    /// capsule badges.
    var tint: Color {
        switch self {
        case .cp: .blue
        case .ctf: .purple
        case .ai: .orange
        case .hackathon: .teal
        case .design: .pink
        case .other: .gray
        }
    }

    /// `shortCode` with a visible fallback for `.other`, for surfaces that
    /// need a label for every category (chips, row meta lines).
    var shortLabel: String {
        shortCode.isEmpty ? "Other" : shortCode
    }

    /// Resolves a widget-snapshot `categoryCode` back to its tint through the
    /// same single mapping. Unknown codes read as uncategorized gray.
    static func tint(forCode code: String) -> Color {
        allCases.first { $0.shortCode == code }?.tint ?? .gray
    }
}

/// The tiny category marker that replaced the filled capsule badges.
public struct CategoryDot: View {
    private let color: Color

    public init(_ category: CompetitionCategory) {
        self.color = category.tint
    }

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}
