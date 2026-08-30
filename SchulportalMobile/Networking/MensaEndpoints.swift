import Foundation

/// `menuebestellung.de` is multi-tenant: every caterer lives under its own path
/// segment and the whole API hangs off it. Ours is `asb-heserv`.
enum MensaEndpoints {
    static let host = "www.menuebestellung.de"
    static let tenant = "asb-heserv"

    static let base = URL(string: "https://\(host)/\(tenant)/")!
    static let origin = "https://\(host)"

    /// The login the site's own form posts to. There is a newer
    /// `api/v1/auth/login` alongside it, but this is the one the website
    /// actually uses, and the one whose answer shape we handle.
    static let login = flag("login_api.php", "loginWithUsernameAndPassword")
    static let loginSecondFactor = base.appendingPathComponent("api/v1/auth/login/2fa")

    /// Balance and statement metadata.
    static let accountOverview = flag("berichte_api.php", "getPageData")
    /// Paged account statement.
    static let transactions = flag("berichte_api.php", "searchTransactions")

    /// The plan itself — server-rendered, and the one page that carries the
    /// week's menus, what is ordered and the balance all at once.
    static func speiseplan(week: String?) -> URL {
        let url = base.appendingPathComponent("speiseplan.php")
        guard let week, !week.isEmpty else { return url }
        return url.appendingQuery(["week": week])
    }

    /// Where the site bounces us when the session is gone.
    static let loginPagePath = "/\(tenant)/login"

    static func isSignedOutURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.path.hasPrefix(loginPagePath)
    }

    /// The API marks its actions with a valueless query flag
    /// (`…?getPageData`), which `URLQueryItem(name:value: nil)` produces.
    private static func flag(_ path: String, _ action: String) -> URL {
        let url = base.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = [URLQueryItem(name: action, value: nil)]
        return components.url ?? url
    }
}
