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
        // Everything below is optional so a payload written by an older
        // build still decodes after an app update.
        /// True in the gap between two lessons — the header then reads
        /// "Pause" instead of "Als Nächstes".
        var isBreak: Bool?
        /// "Entfall", "Vertretung", … when the Vertretungsplan touches the
        /// shown lesson; rendered as a warning badge.
        var substitutionKind: String?
        /// The row's summary: "R101 → R204 · bei Hr. X".
        var substitutionDetail: String?
        /// Open homework for the lesson's subject, tickable right on the
        /// activity — id for the intent, one line of text for the row.
        var homeworkID: String?
        var homeworkText: String?
        var homeworkDone: Bool?
        /// "3.–4." — the shown lesson's periods; nil for own activities.
        var periodLabel: String?
        /// When the day's last lesson ends — "Schluss 15:30".
        var dayEnd: Date?
    }

    /// ISO day the activity belongs to, so yesterday's leftover can be
    /// recognised and ended.
    var isoDay: String
}

extension LessonActivityAttributes.ContentState {
    /// "Gerade" / "Pause" / "Als Nächstes" — the little word above the subject.
    var statusLabel: String {
        if isOngoing { return "Gerade" }
        return (isBreak ?? false) ? "Pause" : "Als Nächstes"
    }

    /// An "Entfall" (and its spellings) reads as cancelled: the subject gets
    /// struck through and the badge turns red instead of orange.
    var isCancelled: Bool {
        substitutionKind?.lowercased().contains("entf") ?? false
    }

    /// The status line with the periods: "Gerade · 3.–4. Stunde".
    var statusLine: String {
        guard let periodLabel else { return statusLabel }
        return "\(statusLabel) · \(periodLabel) Stunde"
    }

    /// What the compact island calls the lesson: the subject, with an arrow
    /// while it is still ahead.
    var compactTitle: String {
        isOngoing ? subject : "→ \(subject)"
    }

    /// What the day still holds after the shown lesson: "Danach: Englisch ·
    /// Schluss 15:30", or "Letzte Stunde" when nothing follows. The Schluss
    /// stays out when it just repeats the shown lesson's own end.
    var followUpLine: String? {
        var parts: [String] = []
        if let nextSubject {
            parts.append("Danach: \(nextSubject)")
        } else if isOngoing {
            parts.append("Letzte Stunde")
        }
        if let dayEnd, dayEnd != end {
            parts.append("Schluss \(Self.timeLabel(dayEnd))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func timeLabel(_ date: Date) -> String {
        let cal = SharedSnapshot.calendar
        return String(format: "%02d:%02d",
                      cal.component(.hour, from: date),
                      cal.component(.minute, from: date))
    }
}
