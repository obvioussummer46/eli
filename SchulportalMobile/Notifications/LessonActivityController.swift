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
        let state = LessonActivityAttributes.ContentState(
            subject: lesson.subject.name,
            room: lesson.room,
            colorHex: lesson.subject.colorHex,
            start: start,
            end: end,
            isOngoing: isOngoing,
            nextSubject: next?.subject.name)
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
}
