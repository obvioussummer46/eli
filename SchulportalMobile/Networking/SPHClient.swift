import Foundation

/// Thin HTTP layer on top of the user's *own* Schulportal session.
///
/// The app never reimplements the portal's login handshake: the user signs in
/// through the real login page inside a `WKWebView` (which handles SSO, 2FA and
/// school specific identity providers for free) and we copy the resulting
/// cookies into this client. From there everything is plain `GET`/`POST`.
actor SPHClient {
    static let shared = SPHClient()

    /// Desktop UA: the portal serves a slimmed-down markup to some mobile
    /// agents and the parsers expect the full desktop tables.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    private let session: URLSession

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

    // MARK: - Requests

    /// `GET` returning decoded HTML. Throws `.notLoggedIn` when the portal
    /// bounced us to the login page.
    func html(_ url: URL, query: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: url.appendingQuery(query))
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        return try await send(request)
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
        return try await send(request)
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

    /// A cheap probe used on launch and before every refresh.
    func verifySession() async -> Bool {
        guard hasSessionCookie else { return false }
        do {
            _ = try await html(SPHEndpoints.startseite)
            return true
        } catch {
            return false
        }
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
