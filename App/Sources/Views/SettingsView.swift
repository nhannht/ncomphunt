#if os(macOS)
import AppKit
#endif
import CompHuntKit
import SwiftUI
// Same Sendable-annotation gap as TranslateControl.swift: LanguageAvailability
// is non-Sendable in the macOS 26 SDK and its async members are nonisolated.
@preconcurrency import Translation
import UniformTypeIdentifiers

/// Settings, one tab per concern.
///
/// macOS renders these as the native Settings-window toolbar tabs (the
/// `Settings` scene gives a `TabView` that treatment for free) - seven
/// sections in one scrolling column meant hunting for the one control you
/// came for. iOS keeps the single grouped list, which is that platform's own
/// settings idiom inside a sheet; the tab split is a desktop fix for a
/// desktop problem.
struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        TabView {
            Tab("Sources", systemImage: "antenna.radiowaves.left.and.right") {
                tabForm { SourcesSettings() }
            }
            Tab("API Keys", systemImage: "key") {
                tabForm { APIKeysSettings() }
            }
            Tab("YouTrack", systemImage: "checklist") {
                tabForm { YouTrackSettings() }
            }
            Tab("Calendar", systemImage: "calendar") {
                tabForm { CalendarSettings() }
            }
            Tab("Notifications", systemImage: "bell.badge") {
                tabForm { NotificationsSettings() }
            }
            Tab("Translation", systemImage: "translate") {
                tabForm { TranslationSettings() }
            }
        }
        #else
        Form {
            SourcesSettings()
            APIKeysSettings()
            YouTrackSettings()
            CalendarSettings()
            NotificationsSettings()
            TranslationSettings()
        }
        .formStyle(.grouped)
        // API keys, engine ids, and URLs: never autocapitalize or "correct".
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        #endif
    }

    #if os(macOS)
    private func tabForm(@ViewBuilder _ content: () -> some View) -> some View {
        Form { content() }
            .formStyle(.grouped)
            .controlSize(.small)
            .frame(width: 460)
    }
    #endif
}

// MARK: - Sources

private struct SourcesSettings: View {
    @Environment(AppModel.self) private var model

    /// Bumped by the API Keys tab after a Save or Import so the rows re-read
    /// `isConfigured`, which reads the Keychain and cannot be observed by
    /// SwiftUI on its own. AppStorage rather than local state because the
    /// writer lives in a different tab.
    @AppStorage("settings.configRevision") private var configRevision = 0

    var body: some View {
        Section("Sources") {
            ForEach(SourceID.allCases) { id in
                SourceToggleRow(id: id, result: lastResult(for: id))
            }
            .id(configRevision)
            Text("Search engines join a refresh at most once per day to stay inside their free API quotas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Refresh") {
            LabeledContent("Interval", value: "On launch, then every 3 hours")
            if let last = model.lastRefresh {
                LabeledContent("Last refresh",
                               value: last.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func lastResult(for id: SourceID) -> RefreshReport.SourceResult? {
        model.lastReport?.results.first { $0.source == id.rawValue }
    }
}

// MARK: - API Keys

private struct APIKeysSettings: View {
    @State private var clistUsername = ""
    @State private var clistAPIKey = ""
    @State private var braveKey = ""
    @State private var googleKey = ""
    @State private var googleCX = ""
    @State private var notice: String?
    @AppStorage("settings.configRevision") private var configRevision = 0
    #if os(iOS)
    @State private var importerPresented = false
    #endif

    var body: some View {
        Section("API Keys") {
            TextField("clist.by username", text: $clistUsername)
            SecureField("clist.by API key", text: $clistAPIKey)
            SecureField("Brave Search API key", text: $braveKey)
            SecureField("Google CSE key", text: $googleKey)
            SecureField("Google CSE engine id (cx)", text: $googleCX)
            HStack {
                Button("Save") { save() }
                Button("Import from secrets.yml...") {
                    #if os(macOS)
                    importSecrets()
                    #else
                    importerPresented = true
                    #endif
                }
                if let notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            .task(id: notice) {
                guard notice != nil else { return }
                try? await Task.sleep(for: .seconds(2.5))
                notice = nil
            }
            Text("Keys are stored in your \(keychainName). Clear a field and Save to remove it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { load() }
        #if os(iOS)
        .fileImporter(
            isPresented: $importerPresented,
            allowedContentTypes: [.yaml, .plainText]
        ) { result in
            guard case .success(let url) = result else { return }
            let count = SecretsImporter.importSecretsYAML(
                at: url, into: KeychainCredentialStore.shared)
            load()
            configRevision += 1
            notice = "Imported \(count) key\(count == 1 ? "" : "s")"
        }
        #endif
    }

    private var keychainName: String {
        #if os(macOS)
        "macOS Keychain"
        #else
        "Keychain"
        #endif
    }

    private func load() {
        let store = KeychainCredentialStore.shared
        clistUsername = store.get(.CLIST_USERNAME) ?? ""
        clistAPIKey = store.get(.CLIST_API_KEY) ?? ""
        braveKey = store.get(.BRAVE_API_KEY) ?? ""
        googleKey = store.get(.GOOGLE_CSE_KEY) ?? ""
        googleCX = store.get(.GOOGLE_CSE_CX) ?? ""
    }

    private func save() {
        let store = KeychainCredentialStore.shared
        persist(clistUsername, to: .CLIST_USERNAME, in: store)
        persist(clistAPIKey, to: .CLIST_API_KEY, in: store)
        persist(braveKey, to: .BRAVE_API_KEY, in: store)
        persist(googleKey, to: .GOOGLE_CSE_KEY, in: store)
        persist(googleCX, to: .GOOGLE_CSE_CX, in: store)
        load()
        configRevision += 1
        notice = "Saved"
    }

    #if os(macOS)
    private func importSecrets() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.allowedContentTypes = [.yaml, .plainText]
        if let claude = realHomeDirectory()?.appending(path: ".claude") {
            panel.directoryURL = claude
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let count = SecretsImporter.importSecretsYAML(at: url, into: KeychainCredentialStore.shared)
        load()
        configRevision += 1
        notice = "Imported \(count) key\(count == 1 ? "" : "s")"
    }

    /// The user's real home; under the sandbox NSHomeDirectory() points into the
    /// container, so read the passwd entry instead to preset the import panel.
    private func realHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
    }
    #endif
}

// MARK: - YouTrack

private struct YouTrackSettings: View {
    @State private var baseURL = ""
    @State private var token = ""
    @State private var notice: String?

    private var configured: Bool {
        SecretsReader.youTrackConfig() != nil
    }

    var body: some View {
        Section("YouTrack") {
            TextField("Base URL", text: $baseURL,
                      prompt: Text("https://youtrack.example.com"))
            SecureField("Permanent token", text: $token)
            HStack {
                Button("Save") { save() }
                if let notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            .task(id: notice) {
                guard notice != nil else { return }
                try? await Task.sleep(for: .seconds(2.5))
                notice = nil
            }
            LabeledContent("Track action target") {
                if configured {
                    Text("Configured (COMP project)").foregroundStyle(.green)
                } else {
                    Text("Not configured").foregroundStyle(.orange)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        let store = KeychainCredentialStore.shared
        baseURL = store.get(.YOUTRACK_BASE_URL) ?? ""
        token = store.get(.YOUTRACK_TOKEN) ?? ""
    }

    private func save() {
        let store = KeychainCredentialStore.shared
        persist(baseURL, to: .YOUTRACK_BASE_URL, in: store)
        persist(token, to: .YOUTRACK_TOKEN, in: store)
        load()
        notice = "Saved"
    }
}

// MARK: - Calendar

private struct CalendarSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Calendar") {
            Toggle(isOn: Binding(
                get: { model.calendarSyncEnabled },
                set: { model.setCalendarSync($0) })
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync to a dedicated nCompHunt calendar")
                    Text(model.calendarStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
            if model.calendarSyncEnabled {
                Button("Remove nCompHunt calendar", role: .destructive) {
                    model.removeCalendar()
                }
            }
            Text("Deadlines and start times stay updated in a dedicated calendar; when a contest date moves, its event updates in place. The one-off \"Add to Calendar\" action stays available per contest.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Notifications

private struct NotificationsSettings: View {
    @Environment(AppModel.self) private var model

    /// The OS permission line. Read asynchronously because
    /// `notificationSettings()` is async, and shown because a denial is
    /// otherwise completely invisible - nothing throws when it happens.
    @State private var status = "Checking..."

    var body: some View {
        Section("Notifications") {
            LabeledContent("Permission", value: status)

            Toggle(isOn: Binding(
                get: { model.digestEnabled },
                set: { model.setDigestEnabled($0) })
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily summary")
                    Text("One post each morning: what closes this week, what is running, what is new. A morning with nothing to say sends nothing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
            if model.digestEnabled {
                DatePicker("Send it at", selection: Binding(
                    get: { model.digestTime },
                    set: { model.setDigestTime($0) }),
                    displayedComponents: .hourAndMinute)
            }

            Toggle(isOn: Binding(
                get: { model.remindersEnabled },
                set: { model.setRemindersEnabled($0) })
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me about competitions I mark")
                    Text("One day and one hour before the deadline, for anything you marked Interested, Applied or Joined. Nothing you have not marked is ever notified about.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
            if model.remindersEnabled {
                LabeledContent("Reminders scheduled",
                               value: "\(model.scheduledReminderCount)")
                // Only when it actually bites. Announcing a ceiling nobody
                // is near would invent a scarcity that no longer exists.
                if model.scheduledReminderCount >= ReminderPlan.defaultLimit {
                    Text("At the \(ReminderPlan.defaultLimit) limit: the nearest deadlines are kept and further ones join as those pass.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .task {
            status = await Notifier.authorizationStatusText()
            model.loadReminderStatus()
        }
    }
}

// MARK: - Translation

private struct TranslationSettings: View {
    @AppStorage(TranslationPreferences.autoKey)
    private var autoTranslate = true
    @AppStorage(TranslationPreferences.languageKey)
    private var readingLanguage = TranslationPreferences.defaultLanguage
    /// Filled from the OS's own list of translatable languages, so the picker
    /// can never offer a language the Translation framework would refuse.
    @State private var readingLanguages: [ReadingLanguage] = []

    var body: some View {
        Section("Translation") {
            Toggle(isOn: $autoTranslate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translate automatically")
                    Text("A competition written in a language other than yours opens already translated, with the original one click away. Off keeps a manual Translate button instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
            Picker("My language", selection: $readingLanguage) {
                ForEach(pickerLanguages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
            Text("On-device Apple translation, nothing leaves this \(deviceName). The first translation into a new language downloads its model once.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await loadReadingLanguages() }
    }

    private var deviceName: String {
        #if os(macOS)
        "Mac"
        #else
        "device"
        #endif
    }

    /// Until the OS list arrives, the picker shows just the stored choice so
    /// the selection is never blank.
    private var pickerLanguages: [ReadingLanguage] {
        readingLanguages.isEmpty
            ? [ReadingLanguage(code: readingLanguage)]
            : readingLanguages
    }

    private func loadReadingLanguages() async {
        let supported = await LanguageAvailability().supportedLanguages
        var seen = Set<String>()
        readingLanguages = supported
            .compactMap { $0.languageCode?.identifier }
            .filter { seen.insert($0).inserted }
            .map(ReadingLanguage.init)
            .sorted { $0.name < $1.name }
    }
}

/// A translatable reading language as the picker shows it: ISO code stored,
/// localized display name shown.
private struct ReadingLanguage: Hashable {
    let code: String
    var name: String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

/// Persists a field, treating an empty or whitespace-only value as a delete.
private func persist(_ value: String, to key: CredentialKey, in store: CredentialStoring) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    store.set(trimmed.isEmpty ? nil : trimmed, for: key)
}

/// One row per source: checkbox + a one-line status that tells the whole
/// story (config missing, last outcome, or ready).
private struct SourceToggleRow: View {
    let id: SourceID
    let result: RefreshReport.SourceResult?

    @AppStorage private var isEnabled: Bool

    init(id: SourceID, result: RefreshReport.SourceResult?) {
        self.id = id
        self.result = result
        self._isEnabled = AppStorage(wrappedValue: true, SourcePreferences.enabledKey(id))
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(id.displayName)
                status
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
    }

    @ViewBuilder
    private var status: some View {
        if !isEnabled {
            Text("Off").foregroundStyle(.secondary)
        } else if !id.isConfigured, let hint = id.configHint {
            Text("Needs \(hint)").foregroundStyle(.orange)
        } else if let result {
            switch result.outcome {
            case .ok:
                Text("\(result.fetched) fetched last run").foregroundStyle(.secondary)
            case .skipped(let reason):
                Text("skipped: \(reason)").foregroundStyle(.orange)
            case .failed(let message):
                Text("failed: \(message)").foregroundStyle(.red)
            }
        } else if id.isSearch {
            Text("Ready (daily)").foregroundStyle(.secondary)
        } else {
            Text("Ready").foregroundStyle(.secondary)
        }
    }
}
