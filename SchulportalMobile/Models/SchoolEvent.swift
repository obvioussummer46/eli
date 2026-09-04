import Foundation
import SwiftUI

/// One entry of the school calendar (`kalender.php`): an excursion, a
/// Klausur, holidays, a parents' evening.
struct SchoolEvent: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var title: String
    /// May carry HTML-ish free text; shown as plain text.
    var description: String
    var place: String?
    /// The category the school filed it under ("Klausuren", "Ferien", …).
    var categoryName: String?
    /// The category's colour as `#rrggbb`; the portal's default blue when
    /// the category is unknown.
    var colorHex: String
    var start: Date
    var end: Date
    var isAllDay: Bool

    var color: Color { Color(hex: colorHex) }

    /// The title with course codes spelled out: "D 05A Arbeit" → "Deutsch-Arbeit".
    var displayTitle: String { SchoolEventText.expand(title) }

    /// The description with the same treatment ("Arbeit in Deutsch (051D01-GYM)").
    var displayDescription: String { SchoolEventText.expand(description) }

    /// A Klassenarbeit, Klausur or Test — either filed under such a category
    /// or announced as one in the title. These come first everywhere.
    var isExam: Bool {
        if let categoryName, SchoolEventText.mentionsExam(categoryName) { return true }
        return SchoolEventText.mentionsExam(title)
    }

    /// Whether the event is still running or ahead at `reference`.
    func isCurrent(at reference: Date = Date()) -> Bool {
        end >= GermanDate.calendar.startOfDay(for: reference)
    }

    /// "Mo, 07.09." / "Mo, 07.09. – Fr, 11.09." / with times when not all-day.
    var dateLabel: String {
        let cal = GermanDate.calendar
        let sameDay = cal.isDate(start, inSameDayAs: end)
            // All-day events often end at 00:00 of the *next* day.
            || (isAllDay && cal.isDate(start, inSameDayAs: end.addingTimeInterval(-60)))
        let startText = GermanDate.shortWeekdayDayMonth.string(from: start)
        if sameDay {
            guard !isAllDay else { return startText }
            let from = String(format: "%02d:%02d", cal.component(.hour, from: start), cal.component(.minute, from: start))
            return "\(startText), \(from) Uhr"
        }
        let endDate = isAllDay ? end.addingTimeInterval(-60) : end
        return "\(startText) – \(GermanDate.shortWeekdayDayMonth.string(from: endDate))"
    }
}

/// Turns the calendar's terse course spellings into readable German.
///
/// Teachers file exams as "D 05A Arbeit" with "Arbeit in D 05A (051D01-GYM)"
/// beneath; the pupil knows their class, so the code becomes the subject
/// and the class token goes.
enum SchoolEventText {
    /// "D 05A Arbeit" → "Deutsch-Arbeit", "M 7c Test" → "Mathematik-Test",
    /// "Arbeit in D 05A (…)" → "Arbeit in Deutsch (…)". Text without a
    /// `CODE CLASS` pair is returned untouched.
    static func expand(_ text: String) -> String {
        var result = ""
        var cursor = text.startIndex
        for match in text.matches(of: coursePattern) {
            guard let name = Subject.names[String(match.1).uppercased()] else { continue }
            result += text[cursor..<match.range.lowerBound]
            cursor = match.range.upperBound
            // A single exam word right after the class glues on with a hyphen.
            if let rest = text[cursor...].prefixMatch(of: /\s+(\p{L}+)\b/), isExamWord(String(rest.1)) {
                result += "\(name)-\(rest.1)"
                cursor = rest.range.upperBound
            } else {
                result += name
            }
        }
        result += text[cursor...]
        return result
    }

    /// `D 05A`, `NAWI 07c`, `M E1` — a subject code followed by a class token.
    private static let coursePattern = /\b([A-ZÄÖÜ]{1,5})\s+(?:0?\d{1,2}[A-Za-z]?|[EQ]\d)\b/

    static func isExamWord(_ word: String) -> Bool {
        examWords.contains(word.lowercased())
    }

    static func mentionsExam(_ text: String) -> Bool {
        text.split(whereSeparator: { !$0.isLetter }).contains { isExamWord(String($0)) }
    }

    private static let examWords: Set<String> = [
        "arbeit", "arbeiten", "klassenarbeit", "klassenarbeiten", "klausur", "klausuren",
        "test", "tests", "prüfung", "prüfungen", "lernkontrolle", "lernkontrollen"
    ]
}
