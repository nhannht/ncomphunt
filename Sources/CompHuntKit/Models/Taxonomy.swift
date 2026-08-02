/// Competition taxonomy shared by sources, classifier, store, and UI.

/// The kinds of competition the index holds.
///
/// The first five cover the tech lane, which is what the app was built for. The
/// four after them exist because the ybox lane brought a different kind of
/// contest entirely - writing, photography, film, business cases, quizzes - and
/// measurement on a live store of 286 rows found that 81 sat in `.other` with
/// ALL of them from ybox. 88% of those had no bucket that could have been
/// correct, so `.other` was recording a gap in this list rather than a failure
/// to classify. See `research/comp-27-classification/`.
///
/// Declaration order here is NOT match priority, and must not be read as it.
/// Priority is the order of `Classifier.keywordCategories`, which deliberately
/// differs from this list: it checks ctf and ai before cp, so a security or an
/// ML contest is not swallowed first by the broader programming keywords.
/// `tags(for:)` returns tags in THAT order and `category(for:)` takes the
/// first, so changing the order here changes nothing about classification.
public enum CompetitionCategory: String, Codable, CaseIterable, Sendable {
    case cp
    case ctf
    case ai
    case hackathon
    case design
    /// The entry itself is text: essay, article, poem, story, slogan, review.
    case writing
    /// The entry is a photograph, video, film, song, or a live performance.
    case media
    /// A business plan, startup pitch, case study, or management problem.
    case business
    /// A test of knowledge or of speaking: maths, quiz, debate, speech.
    case academic
    case other

    public var displayName: String {
        switch self {
        case .cp: "Competitive Programming"
        case .ctf: "CTF"
        case .ai: "AI"
        case .hackathon: "Hackathon"
        case .design: "Design"
        case .writing: "Writing"
        case .media: "Media"
        case .business: "Business"
        case .academic: "Academic"
        case .other: "Other"
        }
    }
}

public enum Region: String, Codable, CaseIterable, Sendable {
    case vietnam
    case global

    public var displayName: String {
        switch self {
        case .vietnam: "Vietnam"
        case .global: "Global"
        }
    }
}
