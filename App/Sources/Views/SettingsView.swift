import CompHuntKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private var youTrackConfigured: Bool {
        SecretsReader.youTrackConfig() != nil
    }

    var body: some View {
        Form {
            Section("Sources") {
                ForEach(SourceID.allCases) { id in
                    SourceToggleRow(id: id, result: lastResult(for: id))
                }
                Text("Search engines join a refresh at most once per day to stay inside their free API quotas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("YouTrack") {
                LabeledContent("Track action target") {
                    if youTrackConfigured {
                        Text("Configured (COMP project)").foregroundStyle(.green)
                    } else {
                        Text("youtrack MCP entry not found in ~/.claude.json")
                            .foregroundStyle(.orange)
                    }
                }
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
    }

    private func lastResult(for id: SourceID) -> RefreshReport.SourceResult? {
        model.lastReport?.results.first { $0.source == id.rawValue }
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
