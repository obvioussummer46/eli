import Foundation

enum MensaError: LocalizedError, Equatable {
    case noCredentials
    case invalidCredentials(String)
    case secondFactorRequired
    case notLoggedIn
    case network(String)
    case badResponse(Int)
    case parsing(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            "Für das Bestellsystem sind keine Zugangsdaten hinterlegt."
        case .invalidCredentials(let detail):
            detail
        case .secondFactorRequired:
            "Dieses Konto verlangt einen zweiten Faktor. Melde dich bitte einmal auf menuebestellung.de an."
        case .notLoggedIn:
            "Die Sitzung beim Bestellsystem ist abgelaufen."
        case .network(let detail):
            "Netzwerkfehler: \(detail)"
        case .badResponse(let code):
            "Das Bestellsystem hat mit Status \(code) geantwortet."
        case .parsing(let what):
            "\(what) konnte nicht gelesen werden. Vermutlich hat menuebestellung.de sein HTML geändert."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noCredentials, .invalidCredentials, .secondFactorRequired:
            "Trage Benutzername und Passwort im Tab „Essen“ neu ein."
        case .network:
            "Prüfe deine Internetverbindung und versuche es noch einmal."
        default:
            nil
        }
    }
}
