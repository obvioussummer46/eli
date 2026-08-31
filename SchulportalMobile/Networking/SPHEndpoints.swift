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
    static let lerngruppen = base.appendingPathComponent("lerngruppen.php")
    static let dateispeicher = base.appendingPathComponent("dateispeicher.php")
    static let dateiverteilung = base.appendingPathComponent("dateiverteilung.php")
    static let videokonferenz = base.appendingPathComponent("videokonferenz.php")
    static let logout = URL(string: "https://start.schulportal.hessen.de/index.php?logout=all")!

    /// After a successful credential POST the login host hands the session to
    /// this host, which in turn redirects to `schulportallogin.php?k=…` on the
    /// start host — the request that finally sets the `sid` cookie.
    static let connect = URL(string: "https://connect.schulportal.hessen.de/")!

    /// Login page. Passing the school id preselects the school so the user only
    /// has to type name + password. The same URL also takes the credential POST
    /// (`user`, `user2`, `password`) for the native sign-in.
    static func login(schoolID: String?) -> URL {
        guard let schoolID, !schoolID.isEmpty else {
            return URL(string: "https://login.schulportal.hessen.de/")!
        }
        return URL(string: "https://login.schulportal.hessen.de/?i=\(schoolID)")!
    }

    /// The public school directory behind the login page's own school picker:
    /// one array of *Schulämter*, each with its schools. Needs no session.
    ///
    /// `?a=schoolonline` — an older spelling of this — now redirects to a
    /// generic HTML page, so a wrong name here fails as unreadable JSON rather
    /// than as a 404.
    static let schoolList = URL(string: "https://startcache.schulportal.hessen.de/exporteur.php?a=schoollist")!

    /// Any host that belongs to the portal — used when deciding whether a
    /// WKWebView navigation stays in-app.
    static func isPortalHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return host.hasSuffix("schulportal.hessen.de") || host.hasSuffix("hessen.de")
    }
}
