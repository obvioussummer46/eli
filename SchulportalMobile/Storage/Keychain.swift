import Foundation
import Security

/// One username + password in the iOS Keychain, per service.
///
/// Both accounts the app can hold — the Schulportal and the mensa — store the
/// same shape: a single account per service, device-only, readable after first
/// unlock so silent background re-logins work. This is the one place that
/// talks to `Security`; `MensaKeychain` and `PortalKeychain` only name the
/// service.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on purpose: background
/// refreshes must be able to read it, but it must never travel to another
/// device or into an iCloud backup.
enum Keychain {
    static func save(service: String, username: String, password: String) {
        clear(service: service)
        guard let data = password.data(using: .utf8) else { return }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Reads back the one stored account. The username is part of the query
    /// result, so nothing outside the Keychain has to remember it.
    static func load(service: String) -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let result = item as? [String: Any],
              let username = result[kSecAttrAccount as String] as? String,
              let data = result[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return (username, password)
    }

    static func clear(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
