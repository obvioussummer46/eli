import Foundation
import Security

struct MensaCredentials: Sendable, Equatable {
    var username: String
    var password: String
}

/// Where the mensa password lives.
///
/// The Schulportal side never sees a password — the user signs in on the
/// portal's own page and we only ever hold a cookie. `menuebestellung.de`
/// offers no such route: it is a plain username/password API, and a session
/// that expires would otherwise put a login screen in front of a child every
/// few hours. So the credentials go into the Keychain and the client re-signs
/// in silently.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on purpose: background
/// refreshes must be able to read it, but it must never travel to another
/// device or into an iCloud backup.
enum MensaKeychain {
    private static let service = "de.schulportalmobile.app.mensa"

    static func save(_ credentials: MensaCredentials) {
        clear()
        guard let data = credentials.password.data(using: .utf8) else { return }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentials.username,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Reads back the one stored account. The username is part of the query
    /// result, so nothing outside the Keychain has to remember it.
    static func load() -> MensaCredentials? {
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
        return MensaCredentials(username: username, password: password)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
