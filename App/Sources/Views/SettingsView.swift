import CompHuntKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private var clistConfigured: Bool {
        SecretsReader.clistCredentials() != nil
    }

    private var youTrackConfigured: Bool {
        SecretsReader.youTrackConfig() != nil
    }

    var body: some View {
        Form {
            Section("Sources") {
                LabeledContent("CTFtime, Devpost, ybox.vn, Contest Watchers") {
                    Text("No configuration needed").foregroundStyle(.secondary)
                }
                LabeledContent("clist.by") {
                    statusText(
                        ok: clistConfigured,
                        okText: "Configured",
                        missingText: "Set CLIST_USERNAME and CLIST_API_KEY in ~/.claude/secrets.yml")
                }
            }
            Section("YouTrack") {
                LabeledContent("Track button target") {
                    statusText(
                        ok: youTrackConfigured,
                        okText: "Configured (COMP project)",
                        missingText: "youtrack MCP entry not found in ~/.claude.json")
                }
            }
            Section("Refresh") {
                LabeledContent("Interval", value: "On launch, then every 3 hours")
                if let last = model.lastRefresh {
                    LabeledContent("Last refresh",
                                   value: last.formatted(date: .abbreviated, time: .shortened))
                }
                if let report = model.lastReport {
                    ForEach(report.results, id: \.source) { result in
                        LabeledContent(result.source) {
                            switch result.outcome {
                            case .ok:
                                Text("\(result.fetched) fetched")
                            case .skipped(let reason):
                                Text("skipped: \(reason)").foregroundStyle(.orange)
                            case .failed(let message):
                                Text("failed: \(message)").foregroundStyle(.red)
                            }
                        }
                        .lineLimit(2)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
    }

    @ViewBuilder
    private func statusText(ok: Bool, okText: String, missingText: String) -> some View {
        if ok {
            Text(okText).foregroundStyle(.green)
        } else {
            Text(missingText).foregroundStyle(.orange)
        }
    }
}
