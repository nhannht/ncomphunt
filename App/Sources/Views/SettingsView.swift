import AppKit
import CompHuntKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var clistUsername = ""
    @State private var clistAPIKey = ""
    @State private var braveKey = ""
    @State private var googleKey = ""
    @State private var googleCX = ""
    @State private var youtrackBaseURL = ""
    @State private var youtrackToken = ""

    /// Bumped after a Save or Import so the Sources rows re-read `isConfigured`,
    /// which reads the Keychain and cannot be observed by SwiftUI on its own.
    @State private var configRevision = 0
    @State private var apiKeysNotice: String?
    @State private var youtrackNotice: String?

    private var youTrackConfigured: Bool {
        SecretsReader.youTrackConfig() != nil
    }

    var body: some View {
        Form {
            Section("Sources") {
                ForEach(SourceID.allCases) { id in
                    SourceToggleRow(id: id, result: lastResult(for: id))
                }
                .id(configRevision)
                Text("Search engines join a refresh at most once per day to stay inside their free API quotas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("API Keys") {
                TextField("clist.by username", text: $clistUsername)
                SecureField("clist.by API key", text: $clistAPIKey)
                SecureField("Brave Search API key", text: $braveKey)
                SecureField("Google CSE key", text: $googleKey)
                SecureField("Google CSE engine id (cx)", text: $googleCX)
                HStack {
                    Button("Save") { saveAPIKeys() }
                    Button("Import from secrets.yml...") { importSecrets() }
                    if let apiKeysNotice {
                        Text(apiKeysNotice)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                Text("Keys are stored in your macOS Keychain. Clear a field and Save to remove it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("YouTrack") {
                TextField("Base URL", text: $youtrackBaseURL,
                          prompt: Text("https://youtrack.example.com"))
                SecureField("Permanent token", text: $youtrackToken)
                HStack {
                    Button("Save") { saveYouTrack() }
                    if let youtrackNotice {
                        Text(youtrackNotice)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                }
                LabeledContent("Track action target") {
                    if youTrackConfigured {
                        Text("Configured (COMP project)").foregroundStyle(.green)
                    } else {
                        Text("Not configured").foregroundStyle(.orange)
                    }
                }
            }
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
                .toggleStyle(.checkbox)
                if model.calendarSyncEnabled {
                    Button("Remove nCompHunt calendar", role: .destructive) {
                        model.removeCalendar()
                    }
                }
                Text("Deadlines and start times stay updated in a dedicated calendar; when a contest date moves, its event updates in place. The one-off \"Add to Calendar\" action stays available per contest.")
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
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { loadCredentials() }
        .task(id: apiKeysNotice) {
            guard apiKeysNotice != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            apiKeysNotice = nil
        }
        .task(id: youtrackNotice) {
            guard youtrackNotice != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            youtrackNotice = nil
        }
    }

    private func lastResult(for id: SourceID) -> RefreshReport.SourceResult? {
        model.lastReport?.results.first { $0.source == id.rawValue }
    }

    private func loadCredentials() {
        let store = KeychainCredentialStore.shared
        clistUsername = store.get(.CLIST_USERNAME) ?? ""
        clistAPIKey = store.get(.CLIST_API_KEY) ?? ""
        braveKey = store.get(.BRAVE_API_KEY) ?? ""
        googleKey = store.get(.GOOGLE_CSE_KEY) ?? ""
        googleCX = store.get(.GOOGLE_CSE_CX) ?? ""
        youtrackBaseURL = store.get(.YOUTRACK_BASE_URL) ?? ""
        youtrackToken = store.get(.YOUTRACK_TOKEN) ?? ""
    }

    private func saveAPIKeys() {
        let store = KeychainCredentialStore.shared
        persist(clistUsername, to: .CLIST_USERNAME, in: store)
        persist(clistAPIKey, to: .CLIST_API_KEY, in: store)
        persist(braveKey, to: .BRAVE_API_KEY, in: store)
        persist(googleKey, to: .GOOGLE_CSE_KEY, in: store)
        persist(googleCX, to: .GOOGLE_CSE_CX, in: store)
        loadCredentials()
        configRevision += 1
        apiKeysNotice = "Saved"
    }

    private func saveYouTrack() {
        let store = KeychainCredentialStore.shared
        persist(youtrackBaseURL, to: .YOUTRACK_BASE_URL, in: store)
        persist(youtrackToken, to: .YOUTRACK_TOKEN, in: store)
        loadCredentials()
        configRevision += 1
        youtrackNotice = "Saved"
    }

    /// Persists a field, treating an empty or whitespace-only value as a delete.
    private func persist(_ value: String, to key: CredentialKey, in store: CredentialStoring) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        store.set(trimmed.isEmpty ? nil : trimmed, for: key)
    }

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
        loadCredentials()
        configRevision += 1
        apiKeysNotice = "Imported \(count) key\(count == 1 ? "" : "s")"
    }

    /// The user's real home; under the sandbox NSHomeDirectory() points into the
    /// container, so read the passwd entry instead to preset the import panel.
    private func realHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
    }
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
        .toggleStyle(.checkbox)
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
