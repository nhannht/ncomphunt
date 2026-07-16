import Foundation
import Security

/// The credentials the app stores, keyed by the same UPPER_SNAKE_CASE names as
/// the ~/.claude/secrets.yml schema so an import from that file maps 1:1.
public enum CredentialKey: String, CaseIterable, Sendable {
    case CLIST_USERNAME
    case CLIST_API_KEY
    case BRAVE_API_KEY
    case GOOGLE_CSE_KEY
    case GOOGLE_CSE_CX
    case YOUTRACK_BASE_URL
    case YOUTRACK_TOKEN
}

/// Best-effort credential storage. `get` never prompts in a loop and never
/// crashes; `set` swallows failures because storage is not on any critical path.
public protocol CredentialStoring: Sendable {
    func get(_ key: CredentialKey) -> String?
    /// A nil value deletes the item.
    func set(_ value: String?, for key: CredentialKey)
}

/// Keychain-backed store using the classic generic-password SecItem APIs.
/// kSecUseDataProtectionKeychain is deliberately not set: ad-hoc-signed debug
/// builds have no keychain-access-group entitlement and must fall back to the
/// file-based login keychain.
public struct KeychainCredentialStore: CredentialStoring {
    public static let shared = KeychainCredentialStore()

    private let service: String

    public init(service: String = "com.nhannht.ncomphunt") {
        self.service = service
    }

    public func get(_ key: CredentialKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func set(_ value: String?, for key: CredentialKey) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        guard let value, let data = value.data(using: .utf8) else {
            _ = SecItemDelete(base as CFDictionary)
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = base
            addQuery[kSecValueData as String] = data
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
