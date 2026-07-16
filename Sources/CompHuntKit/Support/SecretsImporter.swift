import Foundation
import Yams

/// Imports a flat UPPER_SNAKE_CASE secrets.yml into a `CredentialStoring`,
/// mapping each recognized `CredentialKey` 1:1. Shares SecretsReader's filter:
/// empty values and untouched "your-" placeholders are skipped. Lives in the
/// Kit because Yams is a Kit-only dependency.
public enum SecretsImporter {
    /// Writes every matching key from the YAML at `url` into `store` and returns
    /// the number written. Unknown keys are ignored. The security-scoped
    /// accessors are required for a powerbox-granted file under the sandbox and
    /// are harmless otherwise.
    public static func importSecretsYAML(at url: URL, into store: CredentialStoring) -> Int {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard
            let text = try? String(contentsOf: url, encoding: .utf8),
            let root = (try? Yams.load(yaml: text)) as? [String: Any]
        else {
            return 0
        }

        var imported = 0
        for key in CredentialKey.allCases {
            guard let value = root[key.rawValue] as? String,
                  !value.isEmpty, !value.hasPrefix("your-") else { continue }
            store.set(value, for: key)
            imported += 1
        }
        return imported
    }
}
