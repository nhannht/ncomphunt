import Foundation

/// Deterministic self-test source (job-recon fake.py pattern): exercises the
/// full engine path without touching the network.
public struct FakeSource: CompetitionSource {
    public let name = "fake"

    private let dtos: [CompetitionDTO]

    public init(dtos: [CompetitionDTO] = FakeSource.samples) {
        self.dtos = dtos
    }

    public func fetch() async throws -> [CompetitionDTO] {
        dtos
    }

    public static let samples: [CompetitionDTO] = [
        CompetitionDTO(
            source: "fake",
            title: "Fake CTF Championship",
            organizer: "Fake Org",
            url: "https://example.com/fake-ctf",
            category: .ctf,
            location: "Online",
            startDate: Date.now.addingTimeInterval(7 * 24 * 3600),
            endDate: Date.now.addingTimeInterval(8 * 24 * 3600)
        ),
        CompetitionDTO(
            source: "fake",
            title: "Cuộc thi Lập Trình Fake",
            organizer: "Fake VN",
            url: "https://example.vn/fake-cp",
            location: "Hồ Chí Minh",
            registrationDeadline: Date.now.addingTimeInterval(14 * 24 * 3600)
        ),
        CompetitionDTO(
            source: "fake",
            title: "Fake AI Grand Challenge",
            organizer: "Fake Labs",
            url: "https://example.com/fake-ai",
            prize: "$10,000",
            tags: ["Machine Learning/AI"]
        ),
    ]
}
