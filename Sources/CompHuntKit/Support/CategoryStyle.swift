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
        case .writing: .brown
        case .media: .red
        case .business: .green
        case .academic: .indigo
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
///
/// `size` exists because the same marker has to work at two scales. Inline in
/// a row it is a 6pt hint beside text that already names the category, but in
/// the sidebar the dot IS the identity, so it is drawn larger where ten tints
/// have to be told apart from each other.
public struct CategoryDot: View {
    private let color: Color
    private let size: CGFloat

    public init(_ category: CompetitionCategory, size: CGFloat = 6) {
        self.color = category.tint
        self.size = size
    }

    public init(color: Color, size: CGFloat = 6) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
