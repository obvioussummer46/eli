import Foundation
import OSLog

/// HTTP against `menuebestellung.de`.
///
/// Two things make this different from `SPHClient`:
///
/// * **Its own cookie jar.** The configuration is `ephemeral`, so the mensa
///   session lives in a private in-memory store instead of
///   `HTTPCookieStorage.shared`. Signing out of the Schulportal wipes the
///   shared jar wholesale, and it must not take the mensa session with it.
/// * **It can sign itself back in.** The credentials are in the Keychain, so a
///   dead session is a hiccup the client fixes on its own rather than a login
///   screen in the user's way. Every request therefore runs through
///   `authenticated`, which retries exactly once after a fresh sign-in.
actor MensaClient {
    static let shared = MensaClient()

    private let session: URLSession
    /// Held explicitly: `session.configuration` hands back a copy, and the
    /// private jar has to be reachable for `forget()`.
    private let cookieStorage: HTTPCookieStorage?
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "mensa")

    private var credentials: MensaCredentials?
    /// Whether the current cookie jar is believed to hold a live session.
    private var hasSession = false
    /// A sign-in already on the wire. Actors are reentrant, so two refreshes
    /// firing at once would otherwise each start their own login and race over
    /// the session cookie; they wait on this instead.
    private var signInTask: Task<Void, Error>?

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            // Same reasoning as `SPHClient`: ask for the full desktop markup so
            // the parser sees the tables it was written against.
            "User-Agent": SPHClient.userAgent,
            "Accept-Language": "de-DE,de;q=0.9"
        ]
        cookieStorage = config.httpCookieStorage
        session = URLSession(configuration: config)
    }

    // MARK: - Credentials

    /// Hands the client the stored credentials without contacting the server.
    func adopt(_ credentials: MensaCredentials?) {
        self.credentials = credentials
        hasSession = false
        signInTask = nil
    }

    func forget() {
        credentials = nil
        hasSession = false
        signInTask?.cancel()
        signInTask = nil
        cookieStorage?.cookies?.forEach { cookieStorage?.deleteCookie($0) }
    }

    var username: String? { credentials?.username }

    // MARK: - Sign in

    /// Verifies credentials against the site and keeps them for silent
    /// re-logins. Throws `.invalidCredentials` with the site's own wording.
    func signIn(_ credentials: MensaCredentials) async throws {
        try await performSignIn(credentials)
        self.credentials = credentials
    }

    private struct LoginAnswer: Decodable {
        var success: Bool
        var secondFactorRequired: Bool?
        var errors: [String]?
    }

    /// Coalesces concurrent logins onto one request.
    private func performSignIn(_ credentials: MensaCredentials) async throws {
        if let signInTask { return try await signInTask.value }
        let task = Task { try await self.requestSignIn(credentials) }
        signInTask = task
        defer { signInTask = nil }
        try await task.value
    }

    private func requestSignIn(_ credentials: MensaCredentials) async throws {
        var request = URLRequest(url: MensaEndpoints.login)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "username": credentials.username,
            "password": credentials.password
        ])

        let (data, _) = try await send(request)
        guard let answer = try? JSONDecoder().decode(LoginAnswer.self, from: data) else {
            throw MensaError.parsing("Die Antwort der Anmeldung")
        }
        if answer.success {
            hasSession = true
            return
        }
        hasSession = false
        if answer.secondFactorRequired == true { throw MensaError.secondFactorRequired }
        throw MensaError.invalidCredentials(answer.errors?.first ?? "Benutzername oder Passwort stimmen nicht.")
    }

    // MARK: - Requests

    func html(_ url: URL) async throws -> String {
        try await authenticated {
            var request = URLRequest(url: url)
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            let (data, response) = try await self.send(request)
            try Self.rejectIfSignedOut(response)
            return SPHClient.decode(data, response: response)
        }
    }

    func getJSON(_ url: URL) async throws -> Data {
        try await authenticated {
            var request = URLRequest(url: url)
            Self.markAsXHR(&request)
            let (data, response) = try await self.send(request)
            try Self.rejectIfSignedOut(response)
            try Self.rejectHTMLBody(data)
            return data
        }
    }

    func postJSON(_ url: URL, body: [String: Any]) async throws -> Data {
        try await authenticated {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            Self.markAsXHR(&request)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(MensaEndpoints.origin, forHTTPHeaderField: "Origin")
            // The API guards its POSTs with a double-submit cookie: the value
            // of `csrftoken_<tenant>` must come back as `X-CSRFToken`, or the
            // answer is the HTML error page — under a 200, which then reads
            // as a session problem. The cookie arrives with the login, so a
            // fresh sign-in also refreshes the token.
            if let token = self.csrfToken {
                request.setValue(token, forHTTPHeaderField: "X-CSRFToken")
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await self.send(request)
            try Self.rejectIfSignedOut(response)
            try Self.rejectHTMLBody(data)
            return data
        }
    }

    /// The `csrftoken_<tenant>` cookie from the private jar, read at request
    /// time — it changes with every new session.
    private var csrfToken: String? {
        cookieStorage?.cookies?.first { $0.name.hasPrefix("csrftoken") }?.value
    }

    /// The account endpoints are legacy PHP behind a modern front end and they
    /// answer a request that does not look like the site's own `fetch` with the
    /// HTML page instead of JSON — which arrives here as an unreadable body and
    /// used to be blamed on the session. So we say what the browser says.
    private static func markAsXHR(_ request: inout URLRequest) {
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(MensaEndpoints.base.absoluteString, forHTTPHeaderField: "Referer")
    }

    /// Runs `work` with a live session, signing in first if we have none and
    /// once more if the site tells us mid-flight that we do not.
    private func authenticated<T>(_ work: () async throws -> T) async throws -> T {
        guard let credentials else { throw MensaError.noCredentials }
        if !hasSession { try await performSignIn(credentials) }
        do {
            return try await work()
        } catch MensaError.notLoggedIn {
            logger.notice("Sitzung beim Bestellsystem abgelaufen, melde neu an.")
            hasSession = false
            try await performSignIn(credentials)
            do {
                return try await work()
            } catch MensaError.notLoggedIn {
                // A fresh login and still "not logged in": the session was
                // never the problem, and saying so would send the user hunting
                // for a fault in their password.
                throw MensaError.rejected
            }
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw MensaError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw MensaError.network("Unerwartete Antwort")
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw MensaError.notLoggedIn }
        guard (200..<300).contains(http.statusCode) else { throw MensaError.badResponse(http.statusCode) }
        return (data, http)
    }

    /// `URLSession` follows the bounce to `/asb-heserv/login?next=…`
    /// transparently, so a lost session shows up as the final URL.
    private static func rejectIfSignedOut(_ response: HTTPURLResponse) throws {
        if MensaEndpoints.isSignedOutURL(response.url) { throw MensaError.notLoggedIn }
    }

    /// The API endpoints answer a signed-out request with the site's HTML error
    /// page under a 200. Markup where JSON was promised means the session, not
    /// the request, is the problem — so it is worth one silent retry.
    private static func rejectHTMLBody(_ data: Data) throws {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0a, 0x0d]
        guard let first = data.first(where: { !whitespace.contains($0) }) else {
            throw MensaError.notLoggedIn
        }
        if first == UInt8(ascii: "<") { throw MensaError.notLoggedIn }
    }
}
