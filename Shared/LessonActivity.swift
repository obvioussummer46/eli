import ActivityKit
import Foundation

/// The Live Activity's contract between app and widget extension: the
/// current (or next) lesson of the school day. The app starts and updates
/// it in the foreground; there is no push channel, so between updates the
/// system only advances the countdown timers — `staleDate` marks when the
/// shown lesson is over and the content can no longer be trusted.
struct LessonActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var subject: String
        var room: String?
        var colorHex: String
        var start: Date
        var end: Date
        /// `false` while the lesson is still ahead (the timer then counts
        /// down to `start` instead of `end`).
        var isOngoing: Bool
        /// "Danach: Englisch" — nil for the day's last lesson.
        var nextSubject: String?
    }

    /// ISO day the activity belongs to, so yesterday's leftover can be
    /// recognised and ended.
    var isoDay: String
}
