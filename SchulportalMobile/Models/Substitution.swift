import Foundation

/// One row of the Vertretungsplan: a cancelled lesson, a substitute teacher,
/// a room change, …
///
/// Field names follow the portal's own JSON (`Stunde`, `Art`, `Vertreter`, …)
/// translated to English-ish Swift, because that JSON — not any HTML — is the
/// contract: `vertretungsplan.php?a=my` answers with exactly these keys.
struct Substitution: Codable, Equatable, Hashable, Identifiable {
    var id: String
    /// "1", "3 - 4" — the portal sends ranges as free text.
    var period: String
    /// "Entfall", "Vertretung", "Raumvertretung", "Betreuung", …
    var kind: String?
    /// The class(es) affected, as printed: "07C", "7a, 7b", "Ea".
    var className: String?
    var subject: String?
    var previousSubject: String?
    var teacher: String?
    var substitute: String?
    var room: String?
    var previousRoom: String?
    var note: String?

    /// The subject as a full name — the plan prints the course code ("D",
    /// "NAWI"), the card should read "Deutsch". Falls back to the raw text
    /// when the code is unknown.
    var subjectName: String? {
        guard let raw = subject ?? previousSubject, !raw.isEmpty else { return nil }
        return Subject.resolve(fromCourseTitle: raw).name
    }

    /// One compact line for small cards: what changed, where. The `kind`
    /// deliberately stays out — the card renders it as its own badge.
    var summary: String {
        var parts: [String] = []
        if let room, !room.isEmpty {
            if let previousRoom, !previousRoom.isEmpty, previousRoom != room {
                parts.append("\(previousRoom) → \(room)")
            } else {
                parts.append(room)
            }
        }
        if let substitute, !substitute.isEmpty { parts.append("bei \(substitute)") }
        if let note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }
}

/// A day-level announcement above the plan — "7c ganztags Ausflug",
/// "Nachmittagsunterricht entfällt". Header optional: some schools write
/// bare lines.
struct SubstitutionInfo: Codable, Equatable, Hashable {
    var header: String
    var values: [String]
}

/// All substitutions of one school day.
struct SubstitutionDay: Codable, Equatable {
    /// The day, at noon Europe/Berlin (see `GermanDate.firstDate`).
    var date: Date
    var entries: [Substitution] = []
    /// Optional so days stored before this field existed still decode.
    var infos: [SubstitutionInfo]?
}

/// The whole plan as fetched — usually today and the next school day.
struct SubstitutionPlan: Codable, Equatable {
    var days: [SubstitutionDay] = []
    var fetchedAt: Date?

    func day(on date: Date) -> SubstitutionDay? {
        let cal = GermanDate.calendar
        return days.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    /// Entries concerning one class, matched leniently: the plan prints
    /// "07C", the course titles print "07c" or "7c", and multi-class rows
    /// list several. `nil`/empty class on a row means "affects everyone
    /// shown" and is kept.
    static func matches(_ row: Substitution, className: String) -> Bool {
        guard let rowClasses = row.className, !rowClasses.isEmpty else { return true }
        let wanted = normalize(className)
        return rowClasses.split(separator: ",").contains { normalize(String($0)) == wanted }
    }

    /// "07C" → "7c" — case- and leading-zero-insensitive.
    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        while text.count > 1, text.hasPrefix("0") { text.removeFirst() }
        return text
    }
}
