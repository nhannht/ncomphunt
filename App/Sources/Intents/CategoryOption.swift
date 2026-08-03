import AppIntents
import CompHuntKit

/// The kit's `CompetitionCategory` dressed for App Intents: Siri, Shortcuts,
/// and intent parameter pickers need `AppEnum`, and the kit stays
/// framework-free - same reason `CategoryStyle` owns color rather than the
/// model. Raw values match the kit enum one to one, so the bridge is a plain
/// rawValue round trip.
enum CategoryOption: String, AppEnum {
    case cp, ctf, ai, hackathon, design, writing, media, business, academic, other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    /// Mirrors `CompetitionCategory.displayName` exactly, so Siri and the app
    /// never name one category two ways.
    static let caseDisplayRepresentations: [CategoryOption: DisplayRepresentation] = [
        .cp: "Competitive Programming",
        .ctf: "CTF",
        .ai: "AI",
        .hackathon: "Hackathon",
        .design: "Design",
        .writing: "Writing",
        .media: "Media",
        .business: "Business",
        .academic: "Academic",
        .other: "Other",
    ]

    var categoryValue: CompetitionCategory {
        CompetitionCategory(rawValue: rawValue) ?? .other
    }
}
