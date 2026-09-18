import ActivityKit
import Foundation
import OSLog

/// Starts, updates and ends the school-day Live Activity.
///
/// There is no push channel, so the honest contract is: the activity is as
/// fresh as the app's last run. `sync` is called on every foreground
/// activation and every background refresh; between calls the system only
/// advances the countdown timers, and `staleDate` (the shown lesson's end)
/// lets the UI say so instead of pretending. Off by default; besides the
/// in-app toggle, iOS itself lets the user forbid Live Activities per app,
/// which `areActivitiesEnabled` reflects.
@MainActor
enum LessonActivityController {
    private static let logger = Logger(subsystem: "de.schulportalmobile.app", category: "liveactivity")

    /// `canStart: false` from background contexts — ActivityKit only allows
    /// *starting* an activity from the foreground; updating and ending work
    /// from anywhere the app runs.
    static func sync(model: AppModel, canStart: Bool) {
        guard model.settings.showsLiveActivity,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAll()
            return
        }

        let cal = GermanDate.calendar
        let now = Date()
        let today = SharedSnapshot.isoDay.string(from: now)
        let lessons = model.todaysLessons

        // End leftovers from another day, and end the day once the last
        // lesson is over.
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        guard let lastEnd = lessons.map(\.end.minutesFromMidnight).max(), minutes < lastEnd else {
            endAll()
            return
        }

        guard let lesson = model.currentOrNextLesson,
              let start = date(on: now, at: lesson.start),
              let end = date(on: now, at: lesson.end) else {
            endAll()
            return
        }
        let isOngoing = lesson.start.minutesFromMidnight <= minutes
        let next = lessons.first { $0.start.minutesFromMidnight >= lesson.end.minutesFromMidnight }
        let change = substitution(for: lesson, in: model.todaysSubstitutions)
        let task = homework(for: lesson, model: model)
        let state = LessonActivityAttributes.ContentState(
            subject: lesson.subject.name,
            room: lesson.room,
            colorHex: lesson.subject.colorHex,
            start: start,
            end: end,
            isOngoing: isOngoing,
            nextSubject: next?.subject.name,
            isBreak: !isOngoing && lessons.contains { $0.end.minutesFromMidnight <= minutes },
            substitutionKind: change.map { $0.kind ?? "Änderung" },
            substitutionDetail: change.flatMap { $0.summary.isEmpty ? nil : $0.summary },
            homeworkID: task?.id,
            homeworkText: task?.text.components(separatedBy: .newlines).first,
            homeworkDone: task == nil ? nil : false,
            periodLabel: lesson.isActivity ? nil : lesson.periodLabel,
            dayEnd: lessons.map(\.end).max().flatMap { date(on: now, at: $0) })
        let content = ActivityContent(state: state, staleDate: end)

        if let activity = Activity<LessonActivityAttributes>.activities.first {
            if activity.attributes.isoDay == today {
                Task { await activity.update(content) }
            } else {
                endAll()
                start_(content, isoDay: today, canStart: canStart)
            }
        } else {
            start_(content, isoDay: today, canStart: canStart)
        }
    }

    static func endAll() {
        for activity in Activity<LessonActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func start_(_ content: ActivityContent<LessonActivityAttributes.ContentState>,
                               isoDay: String,
                               canStart: Bool) {
        guard canStart else { return }
        do {
            _ = try Activity.request(attributes: LessonActivityAttributes(isoDay: isoDay),
                                     content: content)
        } catch {
            // Typically: the user disabled Live Activities for the app.
            logger.notice("Live-Aktivität nicht gestartet: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func date(on day: Date, at time: TimeOfDay) -> Date? {
        GermanDate.calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
    }

    /// The Vertretungsplan row that touches the shown lesson, matched by
    /// period overlap — the plan prints periods as free text ("3 - 4"), so
    /// the numbers in it become a range. Own activities have no portal
    /// periods and never match. When several rows overlap, a matching
    /// subject wins over the first.
    private static func substitution(for lesson: TimetableEntry,
                                     in rows: [Substitution]) -> Substitution? {
        guard !lesson.isActivity else { return nil }
        let matching = rows.filter { row in
            guard let range = periodRange(row.period) else { return false }
            return range.overlaps(lesson.firstPeriod...lesson.lastPeriod)
        }
        return matching.first { $0.subjectName == lesson.subject.name } ?? matching.first
    }

    private static func periodRange(_ raw: String) -> ClosedRange<Int>? {
        let numbers = raw.matches(of: /\d+/).compactMap { Int($0.output) }
        guard let low = numbers.min(), let high = numbers.max() else { return nil }
        return low...high
    }

    /// The open homework the activity offers to tick: the most urgent one in
    /// the shown lesson's subject. One with a tick the app has not absorbed
    /// yet counts as done already and is skipped.
    private static func homework(for lesson: TimetableEntry, model: AppModel) -> Homework? {
        let pending = SharedHomeworkTicks.load()
        return model.openHomework.first {
            $0.subject.name == lesson.subject.name && pending[$0.id] == nil
        }
    }
}
