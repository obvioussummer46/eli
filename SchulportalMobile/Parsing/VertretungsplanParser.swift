import Foundation
import SwiftSoup

/// Scrapes `vertretungsplan.php` — in two shapes, because the portal has two.
///
/// The page itself is only a shell: day buttons carrying `data-tag="dd.MM.yyyy"`,
/// filled per day by an AJAX POST (`?a=my`, form `tag` + `ganzerPlan=true`)
/// that answers with a JSON array — the reliable, school-independent contract.
/// Schools that switch off "Zugriff auf den gesamten Plan" render classic
/// server-side tables instead (`#tagDD_MM_YYYY` panels with `#vtable…` inside,
/// headers tagged `data-field`), so that shape is parsed as the fallback.
/// The approach mirrors the lanis-mobile project, which runs it statewide.
enum VertretungsplanParser {
    // MARK: - Shell

    /// The days the shell offers, in page order — the dates to ask the AJAX
    /// endpoint about. Empty means: no AJAX interface, try the tables.
    static func dates(inShell html: String) -> [String] {
        var seen = Set<String>()
        var dates: [String] = []
        for match in html.matches(of: /data-tag="(\d{2}\.\d{2}\.\d{4})"/) {
            let date = String(match.1)
            if seen.insert(date).inserted { dates.append(date) }
        }
        return dates
    }

    // MARK: - AJAX day

    /// One `?a=my` answer for one day. The portal sends a JSON array of rows;
    /// a bare number (`-1`) is its way of saying "nothing today".
    static func day(fromAJAX data: Data, date: String) throws -> SubstitutionDay {
        guard let parsed = GermanDate.firstDate(in: date) else {
            throw SPHError.parsing("Der Vertretungsplan")
        }
        let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        if json is NSNumber { return SubstitutionDay(date: parsed) }
        guard let rows = json as? [[String: Any]] else {
            throw SPHError.parsing("Der Vertretungsplan")
        }
        let entries = rows.enumerated().compactMap { index, row -> Substitution? in
            entry(field(row, "Stunde") ?? "",
                  kind: field(row, "Art"),
                  className: field(row, "Klasse"),
                  subject: field(row, "Fach"),
                  previousSubject: field(row, "Fach_alt"),
                  teacher: field(row, "Lehrer") ?? field(row, "Lehrerkuerzel"),
                  substitute: field(row, "Vertreter") ?? field(row, "Vertreterkuerzel"),
                  room: field(row, "Raum"),
                  previousRoom: field(row, "Raum_alt"),
                  note: field(row, "Hinweis"),
                  date: date,
                  position: index)
        }
        return SubstitutionDay(date: parsed, entries: entries)
    }

    private static func field(_ row: [String: Any], _ key: String) -> String? {
        guard let value = row[key] else { return nil }
        let text: String
        switch value {
        case let string as String: text = string
        case let number as NSNumber: text = number.stringValue
        default: return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Table fallback

    /// The classic server-rendered plan: one `#tagDD_MM_YYYY` panel per day,
    /// a `table[id^=vtable]` inside, and every header cell naming its column
    /// in `data-field` — which is what makes this parse layout-independent.
    static func plan(fromShell html: String) throws -> SubstitutionPlan {
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw SPHError.parsing("Der Vertretungsplan")
        }

        var plan = SubstitutionPlan()
        for panel in document.allMatches("[id^=tag]") {
            guard let id = panel.attribute("id"),
                  let match = id.wholeMatch(of: /tag(\d{2})_(\d{2})_(\d{4})/),
                  let date = GermanDate.firstDate(in: "\(match.1).\(match.2).\(match.3)")
            else { continue }

            var day = SubstitutionDay(date: date)
            if let table = panel.firstMatch("table[id^=vtable]") ?? document.firstMatch("#vtable\(id.dropFirst(3))") {
                day.entries = rows(of: table, date: "\(match.1).\(match.2).\(match.3)")
            }
            plan.days.append(day)
        }
        plan.fetchedAt = Date()
        return plan
    }

    private static func rows(of table: Element, date: String) -> [Substitution] {
        var columns: [String: Int] = [:]
        for (index, header) in table.allMatches("th").enumerated() {
            if let fieldName = header.attribute("data-field") { columns[fieldName] = index }
        }
        guard columns["Stunde"] != nil else { return [] }

        var entries: [Substitution] = []
        for (position, row) in table.allMatches("tbody tr").enumerated() {
            // Rows spanning the table are the "keine Einträge" placeholder.
            guard row.allMatches("td[colspan]").isEmpty else { continue }
            let cells = row.allMatches("td")
            func cell(_ name: String) -> String? {
                guard let index = columns[name], index < cells.count else { return nil }
                let text = HTMLText.inline(cells[index])
                return text.isEmpty ? nil : text
            }
            guard let period = cell("Stunde") else { continue }
            if let substitution = entry(period,
                                        kind: cell("Art"),
                                        className: cell("Klasse"),
                                        subject: cell("Fach"),
                                        previousSubject: cell("Fach_alt"),
                                        teacher: cell("Lehrer"),
                                        substitute: cell("Vertreter"),
                                        room: cell("Raum"),
                                        previousRoom: cell("Raum_alt"),
                                        note: cell("Hinweis"),
                                        date: date,
                                        position: position) {
                entries.append(substitution)
            }
        }
        return entries
    }

    // MARK: - Shared

    private static func entry(_ period: String,
                              kind: String?,
                              className: String?,
                              subject: String?,
                              previousSubject: String?,
                              teacher: String?,
                              substitute: String?,
                              room: String?,
                              previousRoom: String?,
                              note: String?,
                              date: String,
                              position: Int) -> Substitution? {
        // A row with no period and no note is decoration, not a substitution.
        guard !period.isEmpty || note != nil else { return nil }
        let id = StableHash.string("\(date)|\(position)|\(period)|\(className ?? "")|\(kind ?? "")|\(subject ?? "")")
        return Substitution(id: id,
                            period: Self.tidyPeriod(period),
                            kind: kind,
                            className: className,
                            subject: subject,
                            previousSubject: previousSubject,
                            teacher: teacher,
                            substitute: substitute,
                            room: room,
                            previousRoom: previousRoom,
                            note: note)
    }

    /// "3 - 4", "3-4", "3./4." → "3–4"; a single "3." → "3".
    static func tidyPeriod(_ raw: String) -> String {
        let numbers = raw.matches(of: /\d+/).map { String($0.0) }
        guard !numbers.isEmpty, numbers.count <= 2 else { return raw }
        return numbers.count == 2 ? "\(numbers[0])–\(numbers[1])" : numbers[0]
    }
}
