import Foundation

/// A fixed weekly appointment the portal knows nothing about: an AG, a
/// Förderkurs, the Hort, the instrument lesson. Entered by the user, kept on
/// the device, and merged into the timetable so it shows up wherever the
/// lessons do — Heute, Plan, the widgets, the calendar export, the digest.
///
/// Deliberately school-agnostic: a school may publish its AG list on a
/// Padlet, a PDF or nowhere at all, and none of that is machine-readable.
/// The user types the one or two they actually attend.
struct SchoolActivity: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var weekday: Weekday
    var start: TimeOfDay
    var end: TimeOfDay
    var room: String?
    /// "AG-Leiter/in" — whoever runs it. Shown where the teacher would be.
    var leader: String?
    var note: String?
    /// `#rrggbb`, derived from the title once so the colour is stable.
    var colorHex: String

    init(id: String = UUID().uuidString,
         title: String,
         weekday: Weekday,
         start: TimeOfDay,
         end: TimeOfDay,
         room: String? = nil,
         leader: String? = nil,
         note: String? = nil,
         colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.weekday = weekday
        self.start = start
        self.end = end
        self.room = room
        self.leader = leader
        self.note = note
        self.colorHex = colorHex ?? Subject.fallbackColor(for: title)
    }

    /// The subject stand-in the timetable views render: the title as the
    /// name, "AG" as the code so a chip can tell it apart from a lesson.
    var subject: Subject {
        Subject(code: Self.subjectCode, name: title, colorHex: colorHex)
    }

    static let subjectCode = "AG"
    static let entryIDPrefix = "activity:"
}

extension Timetable {
    /// The portal's plan plus the user's activities, each activity placed in
    /// the period grid by its times. Everything downstream — day list, week
    /// grid, widgets, calendar — keeps reading plain `TimetableEntry`s.
    func merging(_ activities: [SchoolActivity]) -> Timetable {
        guard !activities.isEmpty else { return self }
        var merged = self
        let slots = periodSlots
        let lastIndex = slots.keys.max() ?? entries.map(\.lastPeriod).max() ?? 0
        for activity in activities {
            // In a period: that period. In a break: the period that follows.
            // After the last period (the usual case): one past it.
            let first = Self.period(containing: activity.start, in: slots)
                ?? Self.period(startingAfter: activity.start, in: slots)
                ?? lastIndex + 1
            // The minute before the end, so an AG ending exactly when a
            // period ends still counts as that period.
            let lastMinute = TimeOfDay(hour: (activity.end.minutesFromMidnight - 1) / 60,
                                       minute: (activity.end.minutesFromMidnight - 1) % 60)
            let last = max(first, Self.period(containing: lastMinute, in: slots) ?? first)
            merged.entries.append(TimetableEntry(
                id: SchoolActivity.entryIDPrefix + activity.id,
                weekday: activity.weekday,
                firstPeriod: first,
                lastPeriod: last,
                start: activity.start,
                end: activity.end,
                rawTitle: activity.title,
                subject: activity.subject,
                room: activity.room,
                teacher: activity.leader,
                activityID: activity.id
            ))
        }
        return merged
    }

    /// Period index → its times, from the portal's period table when it has
    /// one, otherwise reconstructed from single-period lessons.
    private var periodSlots: [Int: (start: TimeOfDay, end: TimeOfDay)] {
        var slots: [Int: (start: TimeOfDay, end: TimeOfDay)] = [:]
        for period in periods {
            slots[period.index] = (period.start, period.end)
        }
        if slots.isEmpty {
            for entry in entries where entry.firstPeriod == entry.lastPeriod && slots[entry.firstPeriod] == nil {
                slots[entry.firstPeriod] = (entry.start, entry.end)
            }
        }
        return slots
    }

    private static func period(containing time: TimeOfDay, in slots: [Int: (start: TimeOfDay, end: TimeOfDay)]) -> Int? {
        slots.first { _, slot in slot.start <= time && time < slot.end }?.key
    }

    private static func period(startingAfter time: TimeOfDay, in slots: [Int: (start: TimeOfDay, end: TimeOfDay)]) -> Int? {
        slots.filter { _, slot in slot.start > time }.keys.min()
    }
}
