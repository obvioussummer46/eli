import Foundation

enum SPHError: LocalizedError, Equatable {
    case notLoggedIn
    /// The portal refused the stored username/password — as opposed to
    /// `.notLoggedIn`, which only means the session is gone.
    case invalidCredentials(String)
    case network(String)
    case badResponse(Int)
    case parsing(String)
    case emptyPage(String)
    case notSupported(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            "Du bist nicht (mehr) am Schulportal angemeldet."
        case .invalidCredentials(let detail):
            detail
        case .network(let detail):
            "Netzwerkfehler: \(detail)"
        case .badResponse(let code):
            "Das Schulportal hat mit Status \(code) geantwortet."
        case .parsing(let what):
            "\(what) konnte nicht gelesen werden. Vermutlich hat das Schulportal sein HTML geändert."
        case .emptyPage(let what):
            "Für \(what) hat das Schulportal nichts geliefert."
        case .notSupported(let what):
            what
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notLoggedIn: "Melde dich erneut an."
        case .invalidCredentials: "Prüfe die Eingaben und den Konto-Typ — Eltern-Konten sind oft „Bildungsserver“. Über die Portalseite klappt es in jedem Fall, auch mit SSO oder Zwei-Faktor."
        case .network: "Prüfe deine Internetverbindung und versuche es noch einmal."
        default: nil
        }
    }
}
