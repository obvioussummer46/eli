import Foundation

struct PortalCredentials: Sendable, Equatable {
    var username: String
    var password: String
}

/// Where the Schulportal password lives — when the user chose to store one.
///
/// Storing it is optional: the browser login (SSO, 2FA, school-specific
/// identity providers) still works without ever handing the app a password.
/// But an SPH session dies after minutes of inactivity, and for a plain
/// username/password account the app can re-enter those credentials itself
/// instead of bouncing a child to a login screen several times a day. They are
/// verified against the portal before they are stored, and `SPHClient` signs
/// itself back in silently — exactly the mensa pattern.
enum PortalKeychain {
    private static let service = "de.schulportalmobile.app.schulportal"

    static func save(_ credentials: PortalCredentials) {
        Keychain.save(service: service, username: credentials.username, password: credentials.password)
    }

    static func load() -> PortalCredentials? {
        guard let stored = Keychain.load(service: service) else { return nil }
        return PortalCredentials(username: stored.username, password: stored.password)
    }

    static func clear() {
        Keychain.clear(service: service)
    }
}
