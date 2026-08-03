import AppIntents

/// Zero-setup Siri phrases. Apple requires the app name inside every phrase,
/// so the issue's headline "when is my next CTF" ships as "... in nCompHunt" -
/// the parameterized \(\.$category) is what lets "CTF" appear in the phrase at
/// all. Registered automatically at install; no user setup.
struct CompHuntShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextCompetitionIntent(),
            phrases: [
                "When is my next competition in \(.applicationName)",
                "What is my next \(\.$category) in \(.applicationName)",
                "Next \(\.$category) in \(.applicationName)",
            ],
            shortTitle: "Next Competition",
            systemImageName: "trophy")
        AppShortcut(
            intent: UpcomingCompetitionsIntent(),
            phrases: [
                "Show upcoming competitions in \(.applicationName)",
                "Upcoming \(\.$category) competitions in \(.applicationName)",
            ],
            shortTitle: "Upcoming Competitions",
            systemImageName: "calendar")
    }
}
