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
        /// When the lesson after the shown one starts — the pause countdown
        /// after the shown lesson expired.
        var nextStart: Date?
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

    /// What the activity is showing right now, staleness resolved. Without
    /// a push channel the views re-render exactly once after the last
    /// update — at `staleDate` — and these moments are what that render can
    /// distinguish: an `upcoming` lesson that went stale has started; a
    /// `running` one that went stale is over, followed by a pause or by the
    /// end of the school day. Nothing here may read the clock — the moment
    /// must be a pure function of the payload and the stale flag.
    enum Moment {
        /// Counting down to `end`.
        case running
        /// Counting down to `start`.
        case upcoming
        /// Over, another lesson ahead: counting down to `nextStart`.
        case pause
        /// Over and nothing follows — the day is done.
        case over
    }

    func moment(isStale: Bool) -> Moment {
        guard isStale else { return isOngoing ? .running : .upcoming }
        if !isOngoing { return .running }
        return nextSubject == nil ? .over : .pause
    }

    /// The headline — during the after-lesson pause the *next* subject is
    /// the news, and after the last one the day itself.
    func title(for moment: Moment) -> String {
        switch moment {
        case .running, .upcoming: subject
        case .pause: nextSubject ?? subject
        case .over: "Schule aus"
        }
    }

    /// What the compact island calls it: the subject, with an arrow for
    /// whatever has not started yet.
    func compactTitle(for moment: Moment) -> String {
        switch moment {
        case .running: subject
        case .upcoming: "→ \(subject)"
        case .pause: "→ \(nextSubject ?? subject)"
        case .over: "Schluss"
        }
    }

    /// The little word above the headline, with the periods while they are
    /// the shown lesson's: "Gerade · 3.–4. Stunde".
    func statusLine(for moment: Moment) -> String {
        switch moment {
        case .running, .upcoming:
            guard let periodLabel else { return statusLabel }
            return "\(statusLabel) · \(periodLabel) Stunde"
        case .pause: return "Pause"
        case .over: return "Geschafft"
        }
    }

    /// Where the countdown runs to — nil once there is nothing left to
    /// count.
    func countdownTarget(for moment: Moment) -> Date? {
        switch moment {
        case .running: end
        case .upcoming: start
        case .pause: nextStart
        case .over: nil
        }
    }

    /// Whether the payload's extras — substitution badge, homework row,
    /// room — still describe what the headline shows. After the stale flip
    /// to the pause they would describe the *previous* lesson.
    func showsLessonDetails(for moment: Moment) -> Bool {
        switch moment {
        case .running, .upcoming: true
        case .pause, .over: false
        }
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
