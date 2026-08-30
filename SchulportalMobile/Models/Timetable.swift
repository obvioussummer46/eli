import Foundation

struct TimeOfDay: Codable, Hashable, Comparable, CustomStringConvertible {
    var hour: Int
    var minute: Int

    var description: String { String(format: "%02d:%02d", hour, minute) }
    var minutesFromMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    /// Parses `"07:45"`, `"7.45"`, `"07:45 Uhr"`.
    init?(_ raw: String) {
        let scanner = raw.replacingOccurrences(of: ".", with: ":")
        guard let match = scanner.range(of: #"(\d{1,2}):(\d{2})"#, options: .regularExpression) else { return nil }
        let parts = scanner[match].split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        hour = h
        minute = m
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var germanName: String {
        switch self {
        case .monday: "Montag"
        case .tuesday: "Dienstag"
        case .wednesday: "Mittwoch"
        case .thursday: "Donnerstag"
        case .friday: "Freitag"
        case .saturday: "Samstag"
        case .sunday: "Sonntag"
        }
    }

    var shortName: String { String(germanName.prefix(2)) }

    /// `Calendar` uses 1 = Sunday.
    var calendarWeekday: Int { self == .sunday ? 1 : rawValue + 1 }

    /// Accepts "Mo", "Mon", "Montag", "MONTAG". The first two letters are
    /// unambiguous for all seven German weekday names.
    static func fromGerman(_ raw: String) -> Weekday? {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 2 else { return nil }
        let stem = key.prefix(2)
        return allCases.first { $0.germanName.lowercased().hasPrefix(stem) }
    }

    static func fromCalendarWeekday(_ value: Int) -> Weekday? {
        value == 1 ? .sunday : Weekday(rawValue: value - 1)
    }
}

/// One block in the weekly timetable. A double lesson is a single entry with
/// `periods = 3...4`.
struct TimetableEntry: Identifiable, Codable, Hashable {
    var id: String
    var weekday: Weekday
    var firstPeriod: Int
    var lastPeriod: Int
    var start: TimeOfDay
    var end: TimeOfDay
    var rawTitle: String
    var subject: Subject
    var room: String?
    var teacher: String?

    var periodLabel: String {
        firstPeriod == lastPeriod ? "\(firstPeriod)." : "\(firstPeriod).–\(lastPeriod)."
    }
}

struct Period: Codable, Hashable, Identifiable {
    var id: Int { index }
    var index: Int
    var start: TimeOfDay
    var end: TimeOfDay
}

struct Timetable: Codable, Hashable {
    var entries: [TimetableEntry] = []
    var periods: [Period] = []
    /// "Gültig ab 01.09.2025", printed above the plan.
    var validFrom: String?
    var fetchedAt: Date?

    var isEmpty: Bool { entries.isEmpty }

    func entries(on weekday: Weekday) -> [TimetableEntry] {
        entries.filter { $0.weekday == weekday }.sorted { $0.firstPeriod < $1.firstPeriod }
    }

    var weekdaysInUse: [Weekday] {
        let used = Set(entries.map(\.weekday))
        return Weekday.allCases.filter { used.contains($0) }
    }
}
