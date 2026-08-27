import Foundation
@preconcurrency import WebKit

/// The session lives in cookies, and two clients need them: the `URLSession`
/// that scrapes, and the `WKWebView`s that log in and render the Portal tab.
/// These helpers keep the two stores in step.
@MainActor
enum SPHCookies {
    /// After a successful web login: hand the session to `URLSession`.
    static func importFromWebView() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        for cookie in cookies where isPortalCookie(cookie) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    /// Before showing the in-app browser: hand the session to the web view so it
    /// does not ask for a second login.
    static func exportToWebView() async {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in cookies where isPortalCookie(cookie) {
            await store.setCookie(cookie)
        }
    }

    static func clearAll() async {
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast)
    }

    private static func isPortalCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
        return SPHEndpoints.isPortalHost(domain)
    }
}
