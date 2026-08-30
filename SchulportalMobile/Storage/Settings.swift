import Foundation
import Observation

/// Small, UserDefaults-backed preferences.
///
/// The values live in one observable struct and are exposed through computed
/// properties that write through to `UserDefaults`. Property observers
/// (`didSet`) are deliberately avoided here: `@Observable` rewrites stored
/// properties into accessors, so mixing the two is asking for trouble.
@Observable
final class Settings {
    private struct Values {
        var schoolID: String
        var schoolName: String
        var calendarIdentifier: String?
        var calendarWeeksAhead: Int
        var syncsHomeworkToCalendar: Bool
        var refreshesOnLaunch: Bool
        var hidesDoneHomework: Bool
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var values: Values

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        values = Values(
            schoolID: defaults.string(forKey: Keys.schoolID) ?? "",
            schoolName: defaults.string(forKey: Keys.schoolName) ?? "",
            calendarIdentifier: defaults.string(forKey: Keys.calendarIdentifier),
            calendarWeeksAhead: defaults.object(forKey: Keys.calendarWeeksAhead) as? Int ?? 4,
            syncsHomeworkToCalendar: defaults.object(forKey: Keys.syncsHomeworkToCalendar) as? Bool ?? false,
            refreshesOnLaunch: defaults.object(forKey: Keys.refreshesOnLaunch) as? Bool ?? true,
            hidesDoneHomework: defaults.object(forKey: Keys.hidesDoneHomework) as? Bool ?? false
        )
    }

    var schoolID: String {
        get { values.schoolID }
        set { values.schoolID = newValue; defaults.set(newValue, forKey: Keys.schoolID) }
    }

    var schoolName: String {
        get { values.schoolName }
        set { values.schoolName = newValue; defaults.set(newValue, forKey: Keys.schoolName) }
    }

    var calendarIdentifier: String? {
        get { values.calendarIdentifier }
        set {
            values.calendarIdentifier = newValue
            if let newValue {
                defaults.set(newValue, forKey: Keys.calendarIdentifier)
            } else {
                defaults.removeObject(forKey: Keys.calendarIdentifier)
            }
        }
    }

    var calendarWeeksAhead: Int {
        get { values.calendarWeeksAhead }
        set { values.calendarWeeksAhead = newValue; defaults.set(newValue, forKey: Keys.calendarWeeksAhead) }
    }

    var syncsHomeworkToCalendar: Bool {
        get { values.syncsHomeworkToCalendar }
        set { values.syncsHomeworkToCalendar = newValue; defaults.set(newValue, forKey: Keys.syncsHomeworkToCalendar) }
    }

    var refreshesOnLaunch: Bool {
        get { values.refreshesOnLaunch }
        set { values.refreshesOnLaunch = newValue; defaults.set(newValue, forKey: Keys.refreshesOnLaunch) }
    }

    var hidesDoneHomework: Bool {
        get { values.hidesDoneHomework }
        set { values.hidesDoneHomework = newValue; defaults.set(newValue, forKey: Keys.hidesDoneHomework) }
    }

    private enum Keys {
        static let schoolID = "school.id"
        static let schoolName = "school.name"
        static let calendarIdentifier = "calendar.identifier"
        static let calendarWeeksAhead = "calendar.weeksAhead"
        static let syncsHomeworkToCalendar = "calendar.homework"
        static let refreshesOnLaunch = "refresh.onLaunch"
        static let hidesDoneHomework = "homework.hideDone"
    }
}
