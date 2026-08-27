import Foundation

enum SPHEndpoints {
    static let startHost = "start.schulportal.hessen.de"
    static let loginHost = "login.schulportal.hessen.de"
    static let connectHost = "connect.schulportal.hessen.de"

    static let base = URL(string: "https://start.schulportal.hessen.de/")!

    static let index = base.appendingPathComponent("index.php")
    static let startseite = base.appendingPathComponent("startseite.php")
    static let meinUnterricht = base.appendingPathComponent("meinunterricht.php")
    static let stundenplan = base.appendingPathComponent("stundenplan.php")
    static let vertretungsplan = base.appendingPathComponent("vertretungsplan.php")
    static let kalender = base.appendingPathComponent("kalender.php")
    static let nachrichten = base.appendingPathComponent("nachrichten.php")
    static let logout = URL(string: "https://start.schulportal.hessen.de/index.php?logout=all")!

    /// Login page. Passing the school id preselects the school so the user only
    /// has to type name + password.
    static func login(schoolID: String?) -> URL {
        guard let schoolID, !schoolID.isEmpty else {
            return URL(string: "https://login.schulportal.hessen.de/")!
        }
        return URL(string: "https://login.schulportal.hessen.de/?i=\(schoolID)")!
    }

    /// The public school directory used by the portal's own search box.
    static let schoolList = URL(string: "https://startcache.schulportal.hessen.de/exporteur.php?a=schoolonline")!

    /// Any host that belongs to the portal — used when deciding whether a
    /// WKWebView navigation stays in-app.
    static func isPortalHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return host.hasSuffix("schulportal.hessen.de") || host.hasSuffix("hessen.de")
    }
}
