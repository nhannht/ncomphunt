import CompHuntKit
import SwiftUI

struct CompetitionDetailView: View {
    let competition: Competition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(competition.title)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                    HStack(spacing: 6) {
                        CategoryChip(category: competition.category)
                        if competition.region == .vietnam {
                            Text("Vietnam").font(.caption).foregroundStyle(.red)
                        }
                        Text("via \(competition.source)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let url = URL(string: competition.url) {
                    Link(destination: url) {
                        Label("Open competition page", systemImage: "safari")
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    if !competition.organizer.isEmpty {
                        detailRow("Organizer", competition.organizer)
                    }
                    if !competition.location.isEmpty {
                        detailRow("Location", competition.location)
                    }
                    if let deadline = competition.registrationDeadline {
                        detailRow("Deadline", deadline.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let start = competition.startDate {
                        detailRow("Starts", start.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let end = competition.endDate {
                        detailRow("Ends", end.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !competition.prize.isEmpty {
                        detailRow("Prize", competition.prize)
                    }
                    detailRow("First seen", competition.firstSeen.formatted(date: .abbreviated, time: .shortened))
                }

                if !competition.details.isEmpty {
                    Divider()
                    Text(competition.details)
                        .font(.body)
                        .textSelection(.enabled)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
