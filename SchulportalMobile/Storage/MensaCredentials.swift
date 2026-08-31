import Foundation

struct MensaCredentials: Sendable, Equatable {
    var username: String
    var password: String
}

/// Where the mensa password lives.
///
/// `menuebestellung.de` offers nothing but a username/password API, and a
/// session that expires would otherwise put a login screen in front of a child
/// every few hours. So the credentials go into the Keychain (see `Keychain`
/// for the storage class) and `MensaClient` re-signs in silently.
enum MensaKeychain {
    private static let service = "de.schulportalmobile.app.mensa"

    static func save(_ credentials: MensaCredentials) {
        Keychain.save(service: service, username: credentials.username, password: credentials.password)
    }

    static func load() -> MensaCredentials? {
        guard let stored = Keychain.load(service: service) else { return nil }
        return MensaCredentials(username: stored.username, password: stored.password)
    }

    static func clear() {
        Keychain.clear(service: service)
    }
}
