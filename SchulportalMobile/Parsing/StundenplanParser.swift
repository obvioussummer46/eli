import Foundation
import SwiftSoup

/// Scrapes `stundenplan.php`.
///
/// The plan is an HTML grid: one row per period, one column per weekday, and
/// double lessons expressed as `rowspan`. We walk it like a spreadsheet so that
/// merged cells land on the right days.
enum StundenplanParser {
    static func parse(html: String) throws -> Timetable {
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw SPHError.parsing("Stundenplan")
        }

        guard let table = findPlanTable(in: document) else {
            throw SPHError.emptyPage("den Stundenplan")
        }

        let columns = weekdayColumns(of: table)
        guard !columns.isEmpty else { throw SPHError.parsing("Stundenplan") }
        let totalColumns = (columns.keys.max() ?? 5) + 1

        let rows = dataRows(of: table)
        guard !rows.isEmpty else { throw SPHError.emptyPage("den Stundenplan") }

        let periods = periodsFor(rows: rows)
        var entries: [TimetableEntry] = []

        // column -> number of *following* rows still covered by a rowspan
        var spans: [Int: Int] = [:]

        for (rowIndex, row) in rows.enumerated() {
            let cells = row.childElements(["td", "th"])
            var cellIndex = 0
            var column = 0

            while column < totalColumns {
                if let remaining = spans[column], remaining > 0 {
                    spans[column] = remaining - 1
                    column += 1
                    continue
                }
                guard cellIndex < cells.count else { break }
                let cell = cells[cellIndex]
                cellIndex += 1

                let colspan = max(1, Int(cell.attribute("colspan") ?? "") ?? 1)
                let rowspan = max(1, Int(cell.attribute("rowspan") ?? "") ?? 1)

                if column > 0 {
                    let lastRow = min(rows.count - 1, rowIndex + rowspan - 1)
                    for offset in 0..<colspan {
                        guard let weekday = columns[column + offset] else { continue }
                        entries.append(contentsOf: lessons(in: cell,
                                                           weekday: weekday,
                                                           from: periods[rowIndex],
                                                           to: periods[lastRow]))
                    }
                }

                if rowspan > 1 {
                    for offset in 0..<colspan { spans[column + offset] = rowspan - 1 }
                }
                column += colspan
            }

            // Columns past the last physical cell still need their span countdown.
            while column < totalColumns {
                if let remaining = spans[column], remaining > 0 { spans[column] = remaining - 1 }
                column += 1
            }
        }

        var timetable = Timetable()
        timetable.entries = dedupe(entries)
        timetable.periods = periods.enumerated().map { Period(index: $0.element.index, start: $0.element.start, end: $0.element.end) }
        timetable.validFrom = validFrom(in: document)
        timetable.fetchedAt = Date()

        if timetable.entries.isEmpty { throw SPHError.emptyPage("den Stundenplan") }
        return timetable
    }

    // MARK: - Table discovery

    private static func findPlanTable(in document: Document) -> Element? {
        for id in ["own", "all", "stundenplan"] {
            if let table = document.firstMatch("table#\(id)"), !table.allMatches(".stunde").isEmpty {
                return table
            }
        }
        if let table = document.allMatches("table").first(where: { !$0.allMatches(".stunde").isEmpty }) {
            return table
        }
        // Some plans render plain cells without `.stunde` wrappers.
        return document.allMatches("table").first { table in
            let headers = table.allMatches("th").map { HTMLText.inline($0) }
            return headers.contains { Weekday.fromGerman($0) != nil }
        }
    }

    /// Maps physical column index -> weekday, from the header row.
    private static func weekdayColumns(of table: Element) -> [Int: Weekday] {
        let headerRow = table.firstMatch("thead tr") ?? table.firstMatch("tr")
        guard let headerRow else { return [:] }
        var mapping: [Int: Weekday] = [:]
        var column = 0
        for cell in headerRow.childElements(["th", "td"]) {
            let colspan = max(1, Int(cell.attribute("colspan") ?? "") ?? 1)
            if let weekday = Weekday.fromGerman(HTMLText.inline(cell)) {
                for offset in 0..<colspan { mapping[column + offset] = weekday }
            }
            column += colspan
        }
        if mapping.isEmpty {
            // No usable header: assume the classic Mon–Fri layout.
            for (offset, day) in [Weekday.monday, .tuesday, .wednesday, .thursday, .friday].enumerated() {
                mapping[offset + 1] = day
            }
        }
        return mapping
    }

    private static func dataRows(of table: Element) -> [Element] {
        let body = table.firstMatch("tbody") ?? table
        var rows = body.childElements(["tr"])
        if rows.isEmpty { rows = table.allMatches("tr") }
        // Drop a leading header row when the table has no <thead>.
        if table.firstMatch("thead") == nil,
           let first = rows.first,
           first.childElements(["th"]).count >= 2,
           first.allMatches(".stunde").isEmpty {
            rows.removeFirst()
        }
        return rows
    }

    // MARK: - Periods

    private struct ParsedPeriod {
        var index: Int
        var start: TimeOfDay
        var end: TimeOfDay
    }

    /// Typical Hessen bell times — used when a plan omits the time column.
    private static let fallbackTimes: [(TimeOfDay, TimeOfDay)] = [
        (.init(hour: 7, minute: 45), .init(hour: 8, minute: 30)),
        (.init(hour: 8, minute: 30), .init(hour: 9, minute: 15)),
        (.init(hour: 9, minute: 35), .init(hour: 10, minute: 20)),
        (.init(hour: 10, minute: 20), .init(hour: 11, minute: 5)),
        (.init(hour: 11, minute: 25), .init(hour: 12, minute: 10)),
        (.init(hour: 12, minute: 10), .init(hour: 12, minute: 55)),
        (.init(hour: 13, minute: 40), .init(hour: 14, minute: 25)),
        (.init(hour: 14, minute: 25), .init(hour: 15, minute: 10)),
        (.init(hour: 15, minute: 20), .init(hour: 16, minute: 5)),
        (.init(hour: 16, minute: 5), .init(hour: 16, minute: 50)),
        (.init(hour: 16, minute: 55), .init(hour: 17, minute: 40))
    ]

    private static func periodsFor(rows: [Element]) -> [ParsedPeriod] {
        rows.enumerated().map { rowIndex, row in
            let first = row.childElements(["td", "th"]).first
            let label = HTMLText.multiline(first)
            let index = Int(label.prefix(while: { $0.isNumber })) ?? (rowIndex + 1)

            let times = label.regexMatches(#"\d{1,2}[:.]\d{2}"#).compactMap { TimeOfDay($0) }
            if times.count >= 2 {
                return ParsedPeriod(index: index, start: times[0], end: times[1])
            }
            let fallback = fallbackTimes[min(max(index, 1) - 1, fallbackTimes.count - 1)]
            return ParsedPeriod(index: index, start: fallback.0, end: fallback.1)
        }
    }

    // MARK: - Cells

    private static func lessons(in cell: Element,
                                weekday: Weekday,
                                from first: ParsedPeriod,
                                to last: ParsedPeriod) -> [TimetableEntry] {
        var blocks = cell.allMatches(".stunde")
        if blocks.isEmpty {
            let text = HTMLText.multiline(cell)
            guard !text.isEmpty else { return [] }
            blocks = [cell]
        }

        return blocks.compactMap { block in
            let title = lessonTitle(in: block)
            guard !title.isEmpty else { return nil }
            let teacher = HTMLText.inline(block.firstMatch("small") ?? block.firstMatch(".lehrer"))
            let room = lessonRoom(in: block, title: title, teacher: teacher)

            let id = StableHash.string("\(weekday.rawValue)|\(first.index)|\(title)|\(room ?? "")")
            return TimetableEntry(id: id,
                                  weekday: weekday,
                                  firstPeriod: first.index,
                                  lastPeriod: max(first.index, last.index),
                                  start: first.start,
                                  end: last.end,
                                  rawTitle: title,
                                  subject: Subject.resolve(fromCourseTitle: title),
                                  room: room,
                                  teacher: teacher.isEmpty ? nil : teacher)
        }
    }

    private static func lessonTitle(in block: Element) -> String {
        let bold = HTMLText.inline(block.firstMatch("b") ?? block.firstMatch("strong"))
        if !bold.isEmpty { return bold }
        let lines = HTMLText.multiline(block).components(separatedBy: "\n")
        return lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func lessonRoom(in block: Element, title: String, teacher: String) -> String? {
        if let explicit = block.firstMatch(".raum") {
            let value = HTMLText.inline(explicit)
            if !value.isEmpty { return value }
        }
        let remainder = HTMLText.multiline(block)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != title && $0 != teacher }
        return remainder.first
    }

    private static func dedupe(_ entries: [TimetableEntry]) -> [TimetableEntry] {
        var seen = Set<String>()
        return entries
            .filter { seen.insert("\($0.weekday.rawValue)|\($0.firstPeriod)|\($0.rawTitle)|\($0.room ?? "")").inserted }
            .sorted { lhs, rhs in
                lhs.weekday.rawValue == rhs.weekday.rawValue
                    ? lhs.firstPeriod < rhs.firstPeriod
                    : lhs.weekday.rawValue < rhs.weekday.rawValue
            }
    }

    private static func validFrom(in document: Document) -> String? {
        for element in document.allMatches("h1, h2, h3, .plan-header, caption") {
            let text = HTMLText.inline(element)
            if text.lowercased().contains("gültig") { return text }
        }
        return nil
    }
}

private extension String {
    /// All matches of a regular expression, as plain strings.
    func regexMatches(_ pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap {
            Range($0.range, in: self).map { String(self[$0]) }
        }
    }
}
