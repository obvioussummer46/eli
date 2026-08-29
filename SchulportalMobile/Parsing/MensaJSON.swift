import Foundation

/// Reading `menuebestellung.de`'s account JSON without trusting its shape.
///
/// The caterer's site is a modern front end over a legacy PHP back end, and the
/// two do not agree on much: money arrives as `"31.85"` on one route and as
/// `31.85` on the next, ids as `12` or `"12"`, timestamps in at least four
/// spellings. `Codable` turns every one of those disagreements into a thrown
/// error that costs the whole list — or, when the wrapper key is the thing that
/// moved, into a silently empty array, which reads as "no bookings" instead of
/// "we looked in the wrong place".
///
/// So the payloads are walked as plain Foundation values and every field is
/// read for its meaning rather than its declared type. Nothing here parses HTML
/// or talks to the network; it is the JSON counterpart to `SpeiseplanParser`.
enum MensaJSON {
    /// The payload as plain values, or `nil` when it is not JSON at all — a few
    /// routes answer with an HTML error page under a `200`.
    static func value(of data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    // MARK: - One object

    /// A JSON object whose fields are looked up by name, case-insensitively and
    /// with `null` treated as absent — the same field is `value` on one route
    /// and `Value` on the next.
    struct Row {
        private let fields: [String: Any]

        init(_ object: [String: Any]) {
            var lowered: [String: Any] = [:]
            lowered.reserveCapacity(object.count)
            for (key, value) in object where !(value is NSNull) {
                lowered[key.lowercased()] = value
            }
            fields = lowered
        }

        /// The first of `keys` the object carries.
        func any(_ keys: [String]) -> Any? {
            for key in keys {
                if let value = fields[key.lowercased()] { return value }
            }
            return nil
        }

        func has(_ keys: [String]) -> Bool { any(keys) != nil }

        func string(_ keys: [String]) -> String? { MensaJSON.string(any(keys)) }
        func decimal(_ keys: [String]) -> Decimal? { MensaJSON.decimal(any(keys)) }
        func date(_ keys: [String]) -> Date? { MensaJSON.date(any(keys)) }
        func row(_ keys: [String]) -> Row? { (any(keys) as? [String: Any]).map(Row.init) }
    }

    // MARK: - Finding the records

    /// Keys the back end has been seen to wrap a record list in.
    static let listKeys = ["data", "transactions", "entries", "rows", "items",
                           "results", "result", "records", "list", "bookings"]

    /// The array of records inside a payload, wherever it hides.
    ///
    /// `matches` is what keeps this honest: an array is only accepted when at
    /// least one of its objects actually looks like the record we are after, so
    /// a stray list of columns or filter presets can never be mistaken for the
    /// statement.
    static func rows(in value: Any?,
                     preferring keys: [String] = listKeys,
                     depth: Int = 5,
                     where matches: (Row) -> Bool) -> [Row] {
        guard depth > 0 else { return [] }

        if let array = value as? [Any] {
            let rows = array.compactMap { ($0 as? [String: Any]).map(Row.init) }
            return rows.contains(where: matches) ? rows : []
        }

        guard let object = value as? [String: Any] else { return [] }
        let wrapper = Row(object)

        for key in keys {
            let found = rows(in: wrapper.any([key]), preferring: keys, depth: depth - 1, where: matches)
            if !found.isEmpty { return found }
        }

        // Nothing under a name we know. Look one level further down, in sorted
        // key order so the answer never depends on dictionary ordering.
        for key in object.keys.sorted() {
            let found = rows(in: object[key], preferring: keys, depth: depth - 1, where: matches)
            if !found.isEmpty { return found }
        }
        return []
    }

    /// Whether the payload carries a record list at all — even an empty one.
    ///
    /// An account that really had no bookings and an answer we are reading in
    /// the wrong place both produce zero rows, and the difference is the whole
    /// point: one is a fact about the card, the other is a bug. Only the former
    /// may be printed as „Keine Buchungen“.
    static func containsList(in value: Any?, preferring keys: [String] = listKeys, depth: Int = 5) -> Bool {
        guard depth > 0 else { return false }
        if value is [Any] { return true }
        guard let object = value as? [String: Any] else { return false }

        let wrapper = Row(object)
        for key in keys {
            if wrapper.any([key]) is [Any] { return true }
        }
        for key in object.keys.sorted() {
            if containsList(in: object[key], preferring: keys, depth: depth - 1) { return true }
        }
        return false
    }

    // MARK: - Scalars

    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    /// Money. Never through a `Double`: the site counts in cents and every one
    /// of them has to survive the trip.
    static func decimal(_ value: Any?) -> Decimal? {
        switch value {
        case let text as String:
            return decimal(fromText: text)
        case let number as NSNumber:
            return Decimal(string: number.stringValue)
        default:
            return nil
        }
    }

    /// `"31.85"`, `"-1,50"`, `"1.234,56"`, `"+ 20,00 €"` — all of them.
    static func decimal(fromText text: String) -> Decimal? {
        guard text.contains(where: isDigit) else { return nil }
        let comma = text.lastIndex(of: ",")
        let dot = text.lastIndex(of: ".")

        let separator: Character?
        switch (comma, dot) {
        case let (comma?, dot?):
            // Both present: the rightmost one separates the cents.
            separator = comma > dot ? "," : "."
        case (.some, .none):
            separator = ","
        case (.none, .some(let dot)):
            // A lone dot with exactly three digits behind it is a German
            // thousands group (`1.234`); anything else is the cents (`31.85`).
            let trailing = text[text.index(after: dot)...].filter(isDigit).count
            separator = trailing == 3 ? nil : "."
        case (.none, .none):
            separator = nil
        }
        return Decimal(string: normalised(text, decimalSeparator: separator))
    }

    /// Every spelling of a timestamp the site has been seen to send.
    static func date(_ value: Any?) -> Date? {
        switch value {
        case let text as String:
            return date(fromText: text)
        case let number as NSNumber:
            return date(fromUnix: number.doubleValue)
        case let object as [String: Any]:
            // `json_encode(new DateTime)`: {"date":"…","timezone_type":3,…}
            return Row(object).string(["date", "datetime"]).flatMap(date(fromText:))
        default:
            return nil
        }
    }

    static func date(fromText raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // A bare number in a string is still a Unix timestamp.
        if text.allSatisfy(isDigit), let seconds = Double(text) { return date(fromUnix: seconds) }

        if let date = isoWithFractionalSeconds.date(from: text) { return date }
        if let date = iso.date(from: text) { return date }
        for formatter in formatters {
            if let date = formatter.date(from: text) { return date }
        }
        // Last resort: a German date somewhere inside a longer string.
        return GermanDate.firstDate(in: text)
    }

    private static func date(fromUnix value: Double) -> Date? {
        // Below 1973 it is not a timestamp but something else read as one — a
        // bare `20260828`, say, which would otherwise land in 1970.
        guard value >= 100_000_000 else { return nil }
        // Anything this large is milliseconds; plain seconds would be far
        // beyond any plausible booking date.
        return Date(timeIntervalSince1970: value > 100_000_000_000 ? value / 1000 : value)
    }

    // MARK: - Helpers

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// Rewrites a printed amount into something `Decimal(string:)` accepts:
    /// digits, one dot, and a leading sign.
    private static func normalised(_ text: String, decimalSeparator: Character?) -> String {
        let isNegative = text.contains("-")
        var whole: String
        var fraction = ""

        if let decimalSeparator, let index = text.lastIndex(of: decimalSeparator) {
            whole = String(text[text.startIndex..<index].filter(isDigit))
            fraction = String(text[text.index(after: index)...].filter(isDigit))
        } else {
            whole = String(text.filter(isDigit))
        }
        if whole.isEmpty { whole = "0" }

        let magnitude = fraction.isEmpty ? whole : "\(whole).\(fraction)"
        return isNegative ? "-\(magnitude)" : magnitude
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Ordered most specific first, so `2026-08-28 12:30:00` is never truncated
    /// to midnight by a date-only pattern that would also have matched.
    private static let formatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss.SSSSSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "dd.MM.yyyy HH:mm:ss",
        "dd.MM.yyyy HH:mm",
        "dd.MM.yyyy",
        "dd.MM.yy"
    ].map { (format: String) -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
