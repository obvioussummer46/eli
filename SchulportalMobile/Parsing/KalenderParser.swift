import Foundation

/// Scrapes `kalender.php` — or rather, reads its JSON: the page answers
/// `?f=getEvents` with a plain array of events, and only the category list
/// (name + colour per id) has to be fished out of the page's own script.
/// The contract follows the lanis-mobile project, which runs it statewide.
enum KalenderParser {
    struct Category {
        var id: String
        var name: String
        var colorHex: String
    }

    // MARK: - Categories

    /// The page pushes its categories in inline JS:
    /// `categories.push({id: 1, name: 'Klausuren', color: '#a2845e', …})`.
    /// Loose JS, not JSON — so the fields are picked out individually and a
    /// malformed line costs only itself.
    static func categories(inShell html: String) -> [Category] {
        var result: [Category] = []
        for match in html.matches(of: /categories\.push\(\s*\{([^}]+)\}/) {
            let body = String(match.1)
            guard let id = firstCapture(in: body, of: /id\s*:\s*['"]?(\d+)/) else { continue }
            let name = firstCapture(in: body, of: /name\s*:\s*['"]([^'"]*)['"]/) ?? ""
            var color = firstCapture(in: body, of: /color\s*:\s*['"](#?[0-9a-fA-F]{3,6})['"]/) ?? ""
            if !color.isEmpty, !color.hasPrefix("#") { color = "#" + color }
            result.append(Category(id: id, name: name, colorHex: color))
        }
        return result
    }

    private static func firstCapture(in text: String, of regex: Regex<(Substring, Substring)>) -> String? {
        guard let match = text.firstMatch(of: regex) else { return nil }
        return String(match.1)
    }

    // MARK: - Events

    /// The default the portal itself paints events in.
    static let fallbackColor = "#4242fc"

    /// The `?f=getEvents` answer. Unreadable rows are dropped one by one —
    /// a single odd event must not wipe the whole calendar.
    static func events(fromJSON data: Data, categories: [Category]) throws -> [SchoolEvent] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SPHError.parsing("Der Kalender")
        }
        let categoryByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return rows.compactMap { row -> SchoolEvent? in
            // The portal's German fields first, the FullCalendar ISO pair as
            // fallback — the same payload carries both.
            guard let start = date(row["Anfang"]) ?? date(row["start"]),
                  let end = date(row["Ende"]) ?? date(row["end"]),
                  let title = text(row["title"]), !title.isEmpty
            else { return nil }

            let category = text(row["category"]).flatMap { categoryByID[$0] }
            let allDay = (row["allDay"] as? Bool) ?? (text(row["allDay"]) == "true")
            let id = text(row["Id"]) ?? StableHash.string("\(title)|\(start.timeIntervalSince1970)")

            return SchoolEvent(id: id,
                               title: title,
                               description: text(row["description"]) ?? "",
                               place: text(row["Ort"]),
                               categoryName: category?.name.isEmpty == false ? category?.name : nil,
                               colorHex: category?.colorHex.isEmpty == false ? category!.colorHex : fallbackColor,
                               start: start,
                               end: end,
                               isAllDay: allDay)
        }
        .sorted { $0.start < $1.start }
    }

    // MARK: - Wire format

    private static func text(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    /// `2026-08-08 10:00:00`, `2026-08-08` or ISO with offset — the three
    /// spellings the endpoint has been seen to send.
    private static func date(_ value: Any?) -> Date? {
        guard let raw = text(value) else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: raw) { return date }
        }
        return iso.date(from: raw)
    }

    private static let formatters: [DateFormatter] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd"
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
