import CompHuntKit
import SwiftData
import SwiftUI

/// The tail of an expanded row: everything the collapsed row does not already
/// say. Rendered inside the List, so there is no ScrollView here and no
/// repeated title - the row above stays visible as the heading.
struct CompetitionExpandedView: View {
    let competition: Competition

    // Display-only translation (COMP-28). The collapsed row above keeps the
    // original title as the heading, so the translated title gets its own
    // line inside the expansion instead of replacing it.
    @State private var translation = TranslationState()
    @State private var translationPair: TranslationPair?
    @AppStorage(TranslationPreferences.autoKey)
    private var autoTranslate = true
    @AppStorage(TranslationPreferences.languageKey)
    private var readingLanguage = TranslationPreferences.defaultLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Every tag, not just the leading one - same as the desktop
                // detail pane.
                ForEach(competition.shownCategoryTags, id: \.self) { tag in
                    Text(tag.shortLabel)
                        .foregroundStyle(tag.tint)
                }
                if competition.region == .vietnam {
                    Text("Vietnam").foregroundStyle(.red)
                }
                Text("via \(competition.source)")
                    .foregroundStyle(.secondary)
                if let issueID = competition.trackedIssueID {
                    Text("tracked \(issueID)")
                        .foregroundStyle(.green)
                }
                TranslateButton(state: $translation, pair: translationPair)
                Spacer()
                // Same reasoning as the desktop pane: the mark is the point of
                // the app, so it sits on the surface, not inside a menu.
                MarkButton(competition: competition)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(competition.isMarked ? .yellow : .secondary)
                Menu {
                    CompetitionActionsMenu(competition: competition)
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif
                .fixedSize()
            }
            .font(.caption2)

            if translation.showingTranslation, let translatedTitle = translation.translatedTitle {
                Text(translatedTitle)
                    .font(.footnote.weight(.semibold))
                    .textSelection(.enabled)
            }

            if competition.isMarked {
                StatusSegments(competition: competition)
                    .font(.caption2)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
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

            if let url = URL(string: competition.url) {
                Link(destination: url) {
                    Label("Open competition page", systemImage: "safari")
                        .font(.footnote)
                }
            }

            if !competition.details.isEmpty {
                Text(translation.details(original: competition.details))
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
        .padding(.leading, 14)
        .padding(.bottom, 4)
        .translationEffect($translation,
                           title: competition.title,
                           details: competition.details)
        .task(id: TranslationTaskKey(id: competition.persistentModelID,
                                     language: readingLanguage,
                                     auto: autoTranslate)) {
            translation.reset()
            translationPair = await TranslationOffer.pair(
                title: competition.title, details: competition.details,
                reader: Locale.Language(identifier: readingLanguage))
            if autoTranslate {
                translation.arm(for: translationPair)
            }
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
        .font(.footnote)
    }
}
