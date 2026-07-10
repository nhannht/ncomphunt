import CompHuntKit
import SwiftUI

struct CompetitionRow: View {
    let competition: Competition

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(competition.title)
                    .font(.headline)
                    .lineLimit(1)
                if competition.isNew() {
                    Text("NEW")
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            HStack(spacing: 6) {
                CategoryChip(category: competition.category)
                if competition.region == .vietnam {
                    Text("VN")
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.red.opacity(0.15), in: Capsule())
                        .foregroundStyle(.red)
                }
                Text(dateLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !competition.prize.isEmpty {
                    Text(competition.prize)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var dateLine: String {
        let now = Date.now
        if let deadline = competition.registrationDeadline {
            return "due \(deadline.formatted(.relative(presentation: .named)))"
        }
        if let start = competition.startDate, start > now {
            return "starts \(start.formatted(.relative(presentation: .named)))"
        }
        if let end = competition.endDate, end > now {
            return "ends \(end.formatted(.relative(presentation: .named)))"
        }
        return competition.source
    }
}

struct CategoryChip: View {
    let category: CompetitionCategory

    var body: some View {
        Text(shortName)
            .font(.caption2.bold())
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var shortName: String {
        switch category {
        case .cp: "CP"
        case .ctf: "CTF"
        case .ai: "AI"
        case .hackathon: "HACK"
        case .design: "DESIGN"
        case .other: "OTHER"
        }
    }

    private var color: Color {
        switch category {
        case .cp: .blue
        case .ctf: .purple
        case .ai: .orange
        case .hackathon: .teal
        case .design: .pink
        case .other: .gray
        }
    }
}
