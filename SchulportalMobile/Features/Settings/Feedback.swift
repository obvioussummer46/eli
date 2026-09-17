import Foundation
import UIKit

/// The feedback channel: one mail address, and a prefilled `mailto:` so every
/// message arrives with the four facts needed to act on it — app version,
/// iOS version, device, Schulnummer. Nothing is sent by the app itself; the
/// user sees the draft in Mail and decides what to send.
enum Feedback {
    static let address = "hello@bittel.app"

    enum Kind {
        /// Free-form: a bug, a wish, a thank-you.
        case general
        /// A school without a profile in the registry — the one mail the app
        /// actively asks for, because it is how the registry grows. The
        /// school itself is never missing: every Hessen school logs in and
        /// gets its timetable; what a profile adds is mensa, links and icon.
        case schoolProfile

        var subject: String {
            switch self {
            case .general: return "Feedback zu Ranzen (Schulportal-App)"
            case .schoolProfile: return "Inhalte für meine Schule in Ranzen (Schulportal-App)"
            }
        }
    }

    /// What the mail body carries about the install. Pure data so the
    /// builder can be tested without a device.
    struct Context: Equatable {
        var schoolID: String
        var schoolName: String
        /// Whether the registry has a profile for this school — the
        /// difference between "the mensa tab is broken" and "the mensa tab
        /// is not configured yet".
        var hasSchoolProfile: Bool
        var appVersion: String
        var buildNumber: String
        var systemVersion: String
        var deviceModel: String

        @MainActor
        static func current(settings: Settings) -> Context {
            let info = Bundle.main.infoDictionary ?? [:]
            return Context(
                schoolID: settings.schoolID,
                schoolName: settings.schoolName,
                hasSchoolProfile: settings.registryConfig != nil,
                appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
                buildNumber: info["CFBundleVersion"] as? String ?? "?",
                systemVersion: UIDevice.current.systemVersion,
                deviceModel: Self.modelIdentifier
            )
        }

        /// `iPhone15,2` rather than the marketing name; it is what bug
        /// reports need and it needs no lookup table.
        private static var modelIdentifier: String {
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafeBytes(of: &systemInfo.machine) { buffer in
                String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
            }
        }
    }

    static func body(for kind: Kind, context: Context) -> String {
        var lines: [String] = []
        switch kind {
        case .general:
            lines.append("Hallo,")
            lines.append("")
            lines.append("")
            lines.append("")
        case .schoolProfile:
            lines.append("Hallo,")
            lines.append("")
            lines.append("meine Schule ist in der App, aber Mensa, Links und Symbol fehlen noch.")
            lines.append("Alles hier ist freiwillig – die Schulnummer unten reicht schon. Was ich weiß:")
            lines.append("- Website der Schule (optional): ")
            lines.append("- Mensa-Anbieter, z. B. Kennung auf menuebestellung.de (optional): ")
            lines.append("- Wichtige Seiten wie Termine, Elternbeirat, AG-Angebot (optional): ")
            lines.append("")
        }
        lines.append("—")
        let school = context.schoolName.isEmpty ? "unbekannt" : context.schoolName
        let schoolID = context.schoolID.isEmpty ? "unbekannt" : context.schoolID
        lines.append("Schule: \(school) (Schulnummer \(schoolID))")
        lines.append("Schulprofil hinterlegt: \(context.hasSchoolProfile ? "ja" : "nein")")
        lines.append("App: \(context.appVersion) (\(context.buildNumber))")
        lines.append("iOS: \(context.systemVersion), \(context.deviceModel)")
        return lines.joined(separator: "\n")
    }

    /// The `mailto:` for Mail (or whatever handles it). `nil` only if the
    /// percent-encoding fails, which it does not for the strings above.
    static func mailURL(for kind: Kind, context: Context) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: kind.subject),
            URLQueryItem(name: "body", value: body(for: kind, context: context))
        ]
        // `URLComponents` leaves "+" and newlines in a shape Mail reads as
        // literal plus signs and drops; encode them the strict way.
        guard let encoded = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
                .replacingOccurrences(of: "\n", with: "%0A")
        else { return nil }
        components.percentEncodedQuery = encoded
        return components.url
    }
}
