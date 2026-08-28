import SwiftUI

/// Maps the terse Hessen course codes ("M 07c GYM", "DW 07c") onto a full
/// subject name and a stable colour.
///
/// This is a direct port of the `SUBJECTS` / `CHIP_COLORS` tables from the
/// `Schulportal Hessen — Mobile` userscript, extended a little.
struct Subject: Codable, Hashable, Identifiable {
    var id: String { code.isEmpty ? name : code }

    /// The course code as it appears in the portal, e.g. `M`, `DW`, `POWI`.
    var code: String
    /// Human readable name, e.g. `Mathematik`.
    var name: String
    /// `#rrggbb`
    var colorHex: String

    var color: Color { Color(hex: colorHex) }

    // MARK: - Catalogue

    static let names: [String: String] = [
        "D": "Deutsch", "DE": "Deutsch",
        "E": "Englisch", "EN": "Englisch",
        "M": "Mathematik", "MA": "Mathematik",
        "DW": "Digitale Welt",
        "MU": "Musik",
        "KU": "Kunst", "K": "Kunst",
        "GEO": "Erdkunde", "EK": "Erdkunde", "ERD": "Erdkunde",
        "ETHI": "Ethik", "ETH": "Ethik",
        "NAWI": "Naturwissenschaften", "NW": "Naturwissenschaften",
        "SPO": "Sport", "SPORT": "Sport", "SP": "Sport",
        "TUT": "Tutorenstunde", "KL": "Klassenlehrerstunde",
        "REV": "Religion (ev.)", "RKA": "Religion (kath.)", "REL": "Religion",
        "RK": "Religion (kath.)", "RE": "Religion (ev.)",
        "BIO": "Biologie", "BI": "Biologie", "B": "Biologie",
        "PH": "Physik", "PHY": "Physik",
        "CH": "Chemie", "CHE": "Chemie",
        "G": "Geschichte", "GE": "Geschichte", "GES": "Geschichte",
        "POWI": "Politik & Wirtschaft", "POWIE": "Politik & Wirtschaft", "PW": "Politik & Wirtschaft",
        "F": "Französisch", "FR": "Französisch",
        "L": "Latein", "LA": "Latein",
        "SPA": "Spanisch", "SN": "Spanisch",
        "INFO": "Informatik", "IT": "Informatik", "INF": "Informatik",
        "DS": "Darstellendes Spiel",
        "GL": "Gesellschaftslehre",
        "AL": "Arbeitslehre",
        "WU": "Wahlunterricht",
        "FÖ": "Förderunterricht", "FOE": "Förderunterricht",
        "AG": "Arbeitsgemeinschaft"
    ]

    static let colors: [String: String] = [
        "Deutsch": "#d70015",
        "Englisch": "#248a3d",
        "Mathematik": "#0040dd",
        "Digitale Welt": "#5856d6",
        "Naturwissenschaften": "#0071a4",
        "Erdkunde": "#a2845e",
        "Kunst": "#c93400",
        "Musik": "#c11f6a",
        "Sport": "#008577",
        "Ethik": "#6c6c70",
        "Tutorenstunde": "#3634a3",
        "Klassenlehrerstunde": "#3634a3",
        "Religion (ev.)": "#8944ab",
        "Religion (kath.)": "#8944ab",
        "Religion": "#8944ab",
        "Geschichte": "#7d5a3c",
        "Biologie": "#2d7d46",
        "Physik": "#005ea3",
        "Chemie": "#9f1d63",
        "Politik & Wirtschaft": "#b25000",
        "Französisch": "#0a6cc4",
        "Latein": "#8e6b23",
        "Spanisch": "#c26100",
        "Informatik": "#4a4a9c",
        "Darstellendes Spiel": "#a5348f",
        "Gesellschaftslehre": "#7d5a3c",
        "Arbeitslehre": "#6b6b70"
    ]

    // MARK: - Resolution

    /// Derives a subject from a raw course title such as `"M 07c GYM"`,
    /// `"DW 07c"`, `"Deutsch 7c"` or `"POWI-GK-1"`.
    static func resolve(fromCourseTitle raw: String) -> Subject {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Subject(code: "", name: "Unterricht", colorHex: "#6e6e73") }

        // First token, cut at whitespace, hyphen, underscore or digit boundary.
        let separators = CharacterSet(charactersIn: " \t-–_/,.")
        let firstToken = trimmed.components(separatedBy: separators).first(where: { !$0.isEmpty }) ?? trimmed
        // Strip a trailing grade suffix that is glued on ("M07c" -> "M").
        let letters = String(firstToken.prefix(while: { $0.isLetter }))
        let key = letters.uppercased()

        if let name = names[key] {
            return Subject(code: letters, name: name, colorHex: colors[name] ?? fallbackColor(for: name))
        }
        // Already a long name in the portal? ("Deutsch 7c")
        if let match = names.values.first(where: { $0.caseInsensitiveCompare(letters) == .orderedSame }) {
            return Subject(code: letters, name: match, colorHex: colors[match] ?? fallbackColor(for: match))
        }
        let display = letters.isEmpty ? trimmed : letters
        return Subject(code: letters, name: display, colorHex: fallbackColor(for: display))
    }

    /// Deterministic hue from the name — same formula as the userscript.
    static func fallbackColor(for name: String) -> String {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hue = Double(sum % 360) / 360.0
        return Color.hexString(hue: hue, saturation: 0.65, brightness: 0.55)
    }

    static let placeholder = Subject(code: "", name: "Unterricht", colorHex: "#6e6e73")
}
