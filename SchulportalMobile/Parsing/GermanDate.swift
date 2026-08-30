import Foundation

/// Everything the portal prints is German and local to Hessen.
enum GermanDate {
    static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current

    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    /// Finds the first `dd.MM.yyyy`, `dd.MM.yy` or `dd.MM.` in a string.
    ///
    /// A date without a year is resolved against `reference` using the school
    /// year: a day more than four months in the past is assumed to belong to
    /// the following calendar year.
    static func firstDate(in raw: String, reference: Date = Date()) -> Date? {
        guard let match = raw.range(of: #"(\d{1,2})\.\s?(\d{1,2})\.(\s?(\d{4}|\d{2}))?"#, options: .regularExpression) else {
            return nil
        }
        let token = String(raw[match])
        let numbers = token
            .replacingOccurrences(of: " ", with: "")
            .split(separator: ".", omittingEmptySubsequences: true)
            .compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }

        let day = numbers[0]
        let month = numbers[1]
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }

        var year: Int
        if numbers.count >= 3 {
            year = numbers[2] < 100 ? 2000 + numbers[2] : numbers[2]
        } else {
            let refYear = calendar.component(.year, from: reference)
            year = refYear
            var guess = DateComponents(year: refYear, month: month, day: day)
            guess.hour = 12
            if let candidate = calendar.date(from: guess) {
                let monthsApart = calendar.dateComponents([.month], from: candidate, to: reference).month ?? 0
                if monthsApart > 4 { year = refYear + 1 }
                if monthsApart < -7 { year = refYear - 1 }
            }
        }

        var components = DateComponents(year: year, month: month, day: day)
        components.hour = 12 // keep it away from DST edges
        return calendar.date(from: components)
    }

    /// Picks a deadline out of free-form homework text: "bis zum 12.09.",
    /// "Abgabe: 12.09.2025", "bis Freitag" is deliberately *not* guessed.
    static func dueDate(in text: String, reference: Date = Date()) -> Date? {
        let patterns = [
            #"(?:bis(?: zum)?|Abgabe:?|fällig(?: am)?|zum)\s*(\d{1,2}\.\s?\d{1,2}\.(\s?\d{2,4})?)"#
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                if let date = firstDate(in: String(text[range]), reference: reference) { return date }
            }
        }
        return nil
    }

    static let dayMonth: DateFormatter = formatter("dd.MM.")
    static let dayMonthYear: DateFormatter = formatter("dd.MM.yyyy")
    static let weekdayDayMonth: DateFormatter = formatter("EEEE, d. MMMM")
    static let shortWeekdayDayMonth: DateFormatter = formatter("EE, dd.MM.")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    /// "heute", "morgen", "Mo, 01.09." — used all over the UI.
    static func relativeLabel(for date: Date, reference: Date = Date()) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: reference),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "heute"
        case 1: return "morgen"
        case -1: return "gestern"
        case 2...6: return shortWeekdayDayMonth.string(from: date)
        default: return dayMonthYear.string(from: date)
        }
    }
}
