import Foundation
import WidgetKit

/// The app's hand-off to everything that runs without it: the widgets and
/// the evening digest. Display-ready values only — no parsing, no models,
/// no networking on the reading side.
///
/// Compiled into both targets. The app writes it into the App Group
/// container after every refresh; the widget extension only ever reads.

struct SharedLesson: Codable, Hashable {
    /// Minutes from midnight — `TimeOfDay` flattened, so this file needs no
    /// app types.
    var startMinutes: Int
    var endMinutes: Int
    var subject: String
    var room: String?
    var colorHex: String

    var startLabel: String { Self.label(startMinutes) }
    var endLabel: String { Self.label(endMinutes) }

    static func label(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

struct SharedSubstitution: Codable, Hashable {
    var date: Date
    var period: String
    var kind: String?
    var subject: String?
    var summary: String
}

struct SharedDeadline: Codable, Hashable {
    var date: Date
    var subject: String
}

/// One open homework, as the interactive widget lists it. The id is the
/// app's own stable homework id, so a tick on the widget maps back exactly.
struct SharedHomework: Codable, Hashable, Identifiable {
    var id: String
    var subject: String
    var colorHex: String
    var text: String
    var deadline: Date?
}

/// One upcoming entry of the school calendar — what the countdown widget
/// counts down to.
struct SharedEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var isExam: Bool
    var isHoliday: Bool
    var colorHex: String
}

struct SharedSnapshot: Codable {
    var updatedAt: Date?
    /// Weekday (1 = Montag … 7 = Sonntag, the app's own numbering) → the
    /// day's lessons, sorted by start.
    var weekdayLessons: [Int: [SharedLesson]] = [:]
    /// Already narrowed to the pupil's class by the app.
    var substitutions: [SharedSubstitution] = []
    /// One entry per open homework with a known deadline.
    var deadlines: [SharedDeadline] = []
    var balanceText: String?
    /// ISO day (`yyyy-MM-dd`) → title of the ordered dish.
    var orderedDishes: [String: String] = [:]
    /// ISO days that have a published menu, are still open for ordering, and
    /// have no order yet — what the Sunday "nichts bestellt" warning reads.
    /// Optional so snapshots written before this field existed still decode.
    var openOrderDays: [String]?
    /// Open homework, soonest deadline first, capped by the app. Optional so
    /// snapshots written before the premium widgets existed still decode.
    var homework: [SharedHomework]?
    /// Upcoming school events, soonest first, capped by the app.
    var events: [SharedEvent]?

    // MARK: - Reading (used by widgets and the digest alike)

    /// Europe/Berlin, Monday-first — deliberately self-contained so the
    /// widget target does not depend on the app's `GermanDate`.
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        cal.firstWeekday = 2
        return cal
    }()

    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func lessons(on date: Date) -> [SharedLesson] {
        let weekday = Self.calendar.component(.weekday, from: date)
        // Calendar counts 1 = Sunday; the app counts 1 = Monday.
        let own = weekday == 1 ? 7 : weekday - 1
        return weekdayLessons[own] ?? []
    }

    func substitutions(on date: Date) -> [SharedSubstitution] {
        substitutions.filter { Self.calendar.isDate($0.date, inSameDayAs: date) }
    }

    func deadlineSubjects(on date: Date) -> [String] {
        var seen = Set<String>()
        return deadlines
            .filter { Self.calendar.isDate($0.date, inSameDayAs: date) }
            .map(\.subject)
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    func orderedDish(on date: Date) -> String? {
        orderedDishes[Self.isoDay.string(from: date)]
    }

    /// The next day with lessons after `date`, up to a week out — tomorrow
    /// on school nights, Monday across the weekend.
    func nextSchoolDay(after date: Date) -> Date? {
        for offset in 1...7 {
            guard let day = Self.calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if !lessons(on: day).isEmpty { return day }
        }
        return nil
    }

    /// Open homework minus the ticks made on the widget itself, so a tapped
    /// row disappears immediately — before the app has absorbed the tick.
    func openHomework(excluding ticked: Set<String> = Set(SharedHomeworkTicks.load().keys)) -> [SharedHomework] {
        (homework ?? []).filter { !ticked.contains($0.id) }
    }

    /// Homework due on `date` (deadline day) among the open ones.
    func homework(dueOn date: Date, excluding ticked: Set<String> = Set(SharedHomeworkTicks.load().keys)) -> [SharedHomework] {
        openHomework(excluding: ticked).filter { item in
            guard let deadline = item.deadline else { return false }
            return Self.calendar.isDate(deadline, inSameDayAs: date)
        }
    }

    /// The next event of a kind that has not started yet — `nil` when the
    /// calendar holds none. Holidays first for the countdown, exams second.
    func nextEvent(after date: Date, where matches: (SharedEvent) -> Bool) -> SharedEvent? {
        let today = Self.calendar.startOfDay(for: date)
        return (events ?? [])
            .filter { matches($0) && Self.calendar.startOfDay(for: $0.start) >= today }
            .min { $0.start < $1.start }
    }

    /// Whole days from `date` to the event's first day: 0 = today.
    static func daysUntil(_ event: SharedEvent, from date: Date) -> Int {
        calendar.dateComponents([.day],
                                from: calendar.startOfDay(for: date),
                                to: calendar.startOfDay(for: event.start)).day ?? 0
    }

    /// The lesson running at `date`, or the next one that day.
    func currentOrNextLesson(at date: Date) -> SharedLesson? {
        let minutes = Self.calendar.component(.hour, from: date) * 60
            + Self.calendar.component(.minute, from: date)
        let today = lessons(on: date)
        if let ongoing = today.first(where: { $0.startMinutes <= minutes && minutes < $0.endMinutes }) {
            return ongoing
        }
        return today.first { $0.startMinutes > minutes }
    }
}

/// Where a tap on a widget lands in the app. The scheme is deliberately not
/// registered in the Info.plist: WidgetKit hands `widgetURL` straight to the
/// containing app's `onOpenURL`, and nothing outside the app should be able
/// to steer its tabs anyway.
enum WidgetLink {
    static let heute = URL(string: "schulportalmobile://tab/heute")!
    static let aufgaben = URL(string: "schulportalmobile://tab/aufgaben")!
    static let plan = URL(string: "schulportalmobile://tab/plan")!
    static let essen = URL(string: "schulportalmobile://tab/essen")!
    /// A locked premium widget lands on the paywall, not on a tab.
    static let paywall = URL(string: "schulportalmobile://paywall")!
}

/// Atomic JSON in the App Group container — the same pattern as
/// `SnapshotStore`, only shared. A missing container (a build signed
/// without the capability) degrades silently: the app keeps working, the
/// widgets show their placeholder.
enum SharedSnapshotStore {
    static let appGroupID = "group.de.schulportalmobile.app"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> SharedSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedSnapshot.self, from: data)
    }

    /// Load-or-new, mutate, save — so the portal and the mensa can each
    /// write only their half without clobbering the other's.
    static func update(_ mutate: (inout SharedSnapshot) -> Void) {
        guard let url = fileURL else { return }
        var snapshot = load() ?? SharedSnapshot()
        mutate(&snapshot)
        snapshot.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
