import EventKit
import Foundation
import OSLog

/// Writes the timetable into a dedicated iOS calendar.
///
/// The plan is materialised as individual events for the next *n* weeks rather
/// than as a recurring rule: timetables change mid-year, and a full rewrite on
/// every sync is both simpler and always correct.
@MainActor
final class CalendarSync {
    struct Summary: Equatable {
        var lessonEvents: Int
        var homeworkEvents: Int
        var removedEvents: Int
        var calendarTitle: String
        var through: Date
    }

    enum SyncError: LocalizedError {
        case accessDenied
        case noWritableCalendar
        case emptyTimetable

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                "Ohne Kalenderzugriff kann der Stundenplan nicht übertragen werden."
            case .noWritableCalendar:
                "Es wurde kein beschreibbarer Kalender gefunden."
            case .emptyTimetable:
                "Es ist noch kein Stundenplan geladen."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .accessDenied: "Erlaube den Zugriff in Einstellungen › Apps › Schulportal › Kalender."
            case .emptyTimetable: "Lade zuerst den Stundenplan im Tab „Plan“."
            case .noWritableCalendar: nil
            }
        }
    }

    static let calendarTitle = "Stundenplan (Schulportal)"

    private let store = EKEventStore()
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "calendar")

    // MARK: - Access

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    @discardableResult
    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    // MARK: - Sync

    func sync(timetable: Timetable, homework: [Homework], settings: Settings) async throws -> Summary {
        guard !timetable.isEmpty else { throw SyncError.emptyTimetable }
        guard try await requestAccess() else { throw SyncError.accessDenied }

        let calendar = try calendarForSync(settings: settings)
        let cal = GermanDate.calendar
        let start = cal.startOfDay(for: Date())
        let weeks = max(1, min(settings.calendarWeeksAhead, 26))
        guard let end = cal.date(byAdding: .weekOfYear, value: weeks, to: start) else {
            throw SyncError.emptyTimetable
        }

        let removed = try removeManagedEvents(in: calendar, from: start, to: end)

        var lessonCount = 0
        for date in schoolDays(from: start, to: end) {
            guard let weekday = Weekday.fromCalendarWeekday(cal.component(.weekday, from: date)) else { continue }
            for entry in timetable.entries(on: weekday) {
                guard let event = makeLessonEvent(entry, on: date, in: calendar) else { continue }
                try store.save(event, span: .thisEvent, commit: false)
                lessonCount += 1
            }
        }

        var homeworkCount = 0
        if settings.syncsHomeworkToCalendar {
            for item in homework {
                guard let due = item.effectiveDate, due >= start, due <= end else { continue }
                let event = makeHomeworkEvent(item, on: due, in: calendar)
                try store.save(event, span: .thisEvent, commit: false)
                homeworkCount += 1
            }
        }

        try store.commit()
        settings.calendarIdentifier = calendar.calendarIdentifier

        logger.info("Kalender synchronisiert: \(lessonCount) Stunden, \(homeworkCount) Hausaufgaben")
        return Summary(lessonEvents: lessonCount,
                       homeworkEvents: homeworkCount,
                       removedEvents: removed,
                       calendarTitle: calendar.title,
                       through: end)
    }

    /// Deletes the calendar the app created, leaving the user's own data alone.
    func removeManagedCalendar(settings: Settings) async throws {
        guard try await requestAccess() else { throw SyncError.accessDenied }
        guard let identifier = settings.calendarIdentifier,
              let calendar = store.calendar(withIdentifier: identifier) else { return }
        try store.removeCalendar(calendar, commit: true)
        settings.calendarIdentifier = nil
    }

    // MARK: - Building blocks

    private func calendarForSync(settings: Settings) throws -> EKCalendar {
        if let identifier = settings.calendarIdentifier,
           let existing = store.calendar(withIdentifier: identifier),
           existing.allowsContentModifications {
            return existing
        }
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.calendarTitle && $0.allowsContentModifications }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.cgColor = PlatformColorBridge.cgColor(hex: "#007aff")
        guard let source = preferredSource() else { throw SyncError.noWritableCalendar }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        settings.calendarIdentifier = calendar.calendarIdentifier
        return calendar
    }

    /// Prefer a synced account so the plan shows up on the Mac too; fall back to
    /// the on-device calendar.
    private func preferredSource() -> EKSource? {
        let sources = store.sources
        if let defaultSource = store.defaultCalendarForNewEvents?.source, sources.contains(defaultSource) {
            return defaultSource
        }
        return sources.first { $0.sourceType == .calDAV && $0.title.lowercased() == "icloud" }
            ?? sources.first { $0.sourceType == .local }
            ?? sources.first
    }

    private func removeManagedEvents(in calendar: EKCalendar, from start: Date, to end: Date) throws -> Int {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let events = store.events(matching: predicate)
        for event in events {
            try store.remove(event, span: .thisEvent, commit: false)
        }
        return events.count
    }

    private func schoolDays(from start: Date, to end: Date) -> [Date] {
        let cal = GermanDate.calendar
        var days: [Date] = []
        var cursor = start
        while cursor < end {
            let weekday = cal.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 { days.append(cursor) }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private func makeLessonEvent(_ entry: TimetableEntry, on day: Date, in calendar: EKCalendar) -> EKEvent? {
        let cal = GermanDate.calendar
        guard let start = cal.date(bySettingHour: entry.start.hour, minute: entry.start.minute, second: 0, of: day),
              let end = cal.date(bySettingHour: entry.end.hour, minute: entry.end.minute, second: 0, of: day),
              end > start else { return nil }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = entry.subject.name
        event.location = entry.room
        event.startDate = start
        event.endDate = end
        event.timeZone = GermanDate.timeZone
        event.url = SPHEndpoints.stundenplan

        var notes = ["Kurs: \(entry.rawTitle)", "Stunde: \(entry.periodLabel)"]
        if let teacher = entry.teacher, !teacher.isEmpty { notes.append("Lehrkraft: \(teacher)") }
        notes.append(Self.signature)
        event.notes = notes.joined(separator: "\n")
        return event
    }

    private func makeHomeworkEvent(_ homework: Homework, on day: Date, in calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.isAllDay = true
        event.startDate = GermanDate.calendar.startOfDay(for: day)
        event.endDate = event.startDate
        event.timeZone = GermanDate.timeZone
        let firstLine = homework.text.components(separatedBy: "\n").first ?? homework.text
        event.title = "📚 \(homework.subject.name): \(firstLine.prefix(60))"
        event.notes = [homework.text, "", Self.signature].joined(separator: "\n")
        event.url = SPHEndpoints.meinUnterricht
        return event
    }

    /// Marker written into every event so a future version can recognise them
    /// even outside the managed calendar.
    static let signature = "— automatisch aus dem Schulportal übertragen"
}
