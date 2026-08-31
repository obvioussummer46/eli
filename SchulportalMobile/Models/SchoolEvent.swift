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
