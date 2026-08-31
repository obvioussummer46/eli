import Foundation

/// Thin HTTP layer on top of the user's *own* Schulportal session.
///
/// Two ways in, the user's choice:
///
/// * **Browser login** — the portal's real login page inside a `WKWebView`,
///   which handles SSO, 2FA and school specific identity providers for free;
///   we only copy the resulting cookies. No password ever reaches the app.
/// * **Stored credentials** — for plain username/password accounts the app can
///   hold the credentials in the Keychain and speak the login form's own POST
///   (`user`, `user2`, `password` against the login host, then
///   `connect.schulportal.hessen.de` hands out the `sid`). That is what lets
///   the client sign itself back in when the short-lived session dies, instead
///   of bouncing the user to a login screen several times a day — the same
///   pattern `MensaClient` uses.
///
/// Either way, from here on everything is plain `GET`/`POST`.
actor SPHClient {
    static let shared = SPHClient()

    /// Desktop UA: the portal serves a slimmed-down markup to some mobile
    /// agents and the parsers expect the full desktop tables.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    private let session: URLSession

    /// Stored credentials for silent re-login, when the user chose to keep
    /// them. `nil` means browser-login only: a dead session then surfaces as
    /// `.notLoggedIn` and the login screen.
    private var credentials: PortalCredentials?
    private var schoolID: String?
    /// A sign-in already on the wire. Actors are reentrant, so two requests
    /// hitting a dead session at once would otherwise each start their own
    /// login; they wait on this instead.
    private var signInTask: Task<Void, Error>?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "User-Agent": Self.userAgent,
            "Accept-Language": "de-DE,de;q=0.9"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Session state

    /// The portal's session id cookie, when present.
    var sessionID: String? {
        HTTPCookieStorage.shared
            .cookies(for: SPHEndpoints.base)?
            .first { $0.name.lowercased() == "sid" }?
            .value
    }

    var hasSessionCookie: Bool { sessionID != nil }

    // MARK: - Credentials

    /// Hands the client stored credentials without contacting the portal —
    /// used on launch, after the Keychain was read.
    func adopt(_ credentials: PortalCredentials?, schoolID: String?) {
        self.credentials = credentials
        self.schoolID = (schoolID?.isEmpty == false) ? schoolID : nil
        signInTask = nil
    }

    /// Verifies credentials against the portal and keeps them for silent
    /// re-logins. Throws `.invalidCredentials` when the portal refused them.
    func signIn(_ credentials: PortalCredentials, schoolID: String) async throws {
        self.credentials = nil
        self.schoolID = nil
        try await requestSignIn(credentials, schoolID: schoolID)
        self.credentials = credentials
        self.schoolID = schoolID
    }

    /// Coalesces concurrent re-logins onto one request.
    private func performSignIn(_ credentials: PortalCredentials, schoolID: String) async throws {
        if let signInTask { return try await signInTask.value }
        let task = Task { try await self.requestSignIn(credentials, schoolID: schoolID) }
        signInTask = task
        defer { signInTask = nil }
        try await task.value
    }

    /// The login form's own POST. `URLSession` chases the redirect chain
    /// (login host → `connect` → `schulportallogin.php?k=…`) transparently,
    /// and the last hop is the one that sets the `sid` cookie — so success is
    /// "we ended up on the start host with a session", and a wrong password is
    /// the login page rendered again.
    private func requestSignIn(_ credentials: PortalCredentials, schoolID: String) async throws {
        // A leftover `sid` from the dead session would make that check lie.
        clearSessionCookie()

        var request = URLRequest(url: SPHEndpoints.login(schoolID: schoolID))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        // The login page's own submit handler: school-issued accounts send
        // `user` as "<schoolID>.<name>", Bildungsserver accounts ("Login
        // ohne Schulbezug", `i=-1`) send the bare name.
        let qualified = (schoolID.isEmpty || schoolID == "-1")
            ? credentials.username
            : "\(schoolID).\(credentials.username)"
        request.httpBody = Self.formBody([
            "user": qualified,
            "user2": credentials.username,
            "password": credentials.password
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw SPHError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SPHError.network("Unerwartete Antwort")
        }
        guard http.statusCode != 503 else { throw SPHError.badResponse(503) }

        if landedInSession(http) { return }
        // Some answers stop the chain at the login host even on success;
        // `connect` then hands the session over on request.
        if let (_, connectResponse) = try? await session.data(from: SPHEndpoints.connect),
           let connectHTTP = connectResponse as? HTTPURLResponse,
           landedInSession(connectHTTP) {
            return
        }

        let body = Self.decode(data, response: http)
        if body.contains("authErrorLocktime") {
            throw SPHError.invalidCredentials("Zu viele Fehlversuche — das Schulportal sperrt die Anmeldung kurz. Warte einen Moment und versuche es dann erneut.")
        }
        throw SPHError.invalidCredentials("Das Schulportal hat Benutzername oder Passwort nicht akzeptiert.")
    }

    private func landedInSession(_ response: HTTPURLResponse) -> Bool {
        response.url?.host == SPHEndpoints.startHost && hasSessionCookie
    }

    private func clearSessionCookie() {
        let store = HTTPCookieStorage.shared
        store.cookies(for: SPHEndpoints.base)?
            .filter { $0.name.lowercased() == "sid" }
            .forEach { store.deleteCookie($0) }
    }

    // MARK: - Requests

    /// `GET` returning decoded HTML. Throws `.notLoggedIn` when the portal
    /// bounced us to the login page.
    func html(_ url: URL, query: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: url.appendingQuery(query))
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        return try await sendAuthenticated(request)
    }

    /// `POST` with a form-urlencoded body — the portal's AJAX endpoints all
    /// speak this dialect.
    @discardableResult
    func postForm(_ url: URL, fields: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(SPHEndpoints.base.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = Self.formBody(fields)
        return try await sendAuthenticated(request)
    }

    /// `send`, but with one silent re-login when the session is dead and
    /// credentials are stored. A second `.notLoggedIn` right after a fresh
    /// login propagates — the session was not the problem then.
    private func sendAuthenticated(_ request: URLRequest) async throws -> String {
        do {
            return try await send(request)
        } catch SPHError.notLoggedIn {
            guard let credentials, let schoolID else { throw SPHError.notLoggedIn }
            try await performSignIn(credentials, schoolID: schoolID)
            return try await send(request)
        }
    }

    private func send(_ request: URLRequest) async throws -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw SPHError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SPHError.network("Unerwartete Antwort")
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw SPHError.notLoggedIn }
        guard (200..<300).contains(http.statusCode) else { throw SPHError.badResponse(http.statusCode) }

        // `URLSession` follows redirects transparently, so a bounce to the login
        // host shows up as the final URL.
        if let host = http.url?.host, host == SPHEndpoints.loginHost {
            throw SPHError.notLoggedIn
        }

        let body = Self.decode(data, response: http)
        if Self.looksLikeLoginWall(body) { throw SPHError.notLoggedIn }
        return body
    }

    /// A cheap probe used on launch. With stored credentials it doubles as the
    /// launch login: `html` re-signs in on its own when the cookie is missing
    /// or stale. A rejected *credential* throws rather than reading as "no
    /// session" — the caller must drop it, or every launch retries a wrong
    /// password in silence.
    func verifySession() async throws -> Bool {
        guard hasSessionCookie || credentials != nil else { return false }
        do {
            _ = try await html(SPHEndpoints.startseite)
            return true
        } catch let error as SPHError where isCredentialRejection(error) {
            throw error
        } catch {
            return false
        }
    }

    private func isCredentialRejection(_ error: SPHError) -> Bool {
        if case .invalidCredentials = error { return true }
        return false
    }

    // MARK: - Helpers

    static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = fields.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }
        return encoded.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    /// SPH is UTF-8 nowadays but a few legacy pages still ship Latin-1.
    static func decode(_ data: Data, response: HTTPURLResponse?) -> String {
        if let charset = response?.textEncodingName,
           charset.lowercased().contains("8859") || charset.lowercased().contains("1252"),
           let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    /// Two unambiguous markers: the portal's "session expired" interstitial and
    /// the login form itself, which is the only form posting to the login host.
    static func looksLikeLoginWall(_ html: String) -> Bool {
        html.contains("Sitzung abgelaufen")
            || html.contains("action=\"https://login.schulportal.hessen.de")
    }
}

extension URL {
    func appendingQuery(_ items: [String: String]) -> URL {
        guard !items.isEmpty, var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var existing = components.queryItems ?? []
        existing.append(contentsOf: items.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = existing
        return components.url ?? self
    }

    var queryValues: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [:] }
        return Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }, uniquingKeysWith: { _, last in last })
    }
}
