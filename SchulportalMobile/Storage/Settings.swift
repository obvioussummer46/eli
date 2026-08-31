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
        var loginID: String
        var calendarIdentifier: String?
        var calendarWeeksAhead: Int
        var syncsHomeworkToCalendar: Bool
        var refreshesOnLaunch: Bool
        var hidesDoneHomework: Bool
        var notifiesHomework: Bool
        var notifiesLowBalance: Bool
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var values: Values

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        values = Values(
            schoolID: defaults.string(forKey: Keys.schoolID) ?? "",
            schoolName: defaults.string(forKey: Keys.schoolName) ?? "",
            loginID: defaults.string(forKey: Keys.loginID) ?? "",
            calendarIdentifier: defaults.string(forKey: Keys.calendarIdentifier),
            calendarWeeksAhead: defaults.object(forKey: Keys.calendarWeeksAhead) as? Int ?? 4,
            syncsHomeworkToCalendar: defaults.object(forKey: Keys.syncsHomeworkToCalendar) as? Bool ?? false,
            refreshesOnLaunch: defaults.object(forKey: Keys.refreshesOnLaunch) as? Bool ?? true,
            hidesDoneHomework: defaults.object(forKey: Keys.hidesDoneHomework) as? Bool ?? false,
            notifiesHomework: defaults.object(forKey: Keys.notifiesHomework) as? Bool ?? false,
            notifiesLowBalance: defaults.object(forKey: Keys.notifiesLowBalance) as? Bool ?? false
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

    /// What went into the login page's `?i=` for the native sign-in: the
    /// school number for school-issued accounts, `-1` for Bildungsserver
    /// accounts ("Login ohne Schulbezug" — typically parents). Kept apart
    /// from `schoolID`, which stays the *school*, whoever is logged in.
    var loginID: String {
        get { values.loginID }
        set { values.loginID = newValue; defaults.set(newValue, forKey: Keys.loginID) }
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

    var notifiesHomework: Bool {
        get { values.notifiesHomework }
        set { values.notifiesHomework = newValue; defaults.set(newValue, forKey: Keys.notifiesHomework) }
    }

    var notifiesLowBalance: Bool {
        get { values.notifiesLowBalance }
        set { values.notifiesLowBalance = newValue; defaults.set(newValue, forKey: Keys.notifiesLowBalance) }
    }

    private enum Keys {
        static let schoolID = "school.id"
        static let schoolName = "school.name"
        static let loginID = "login.id"
        static let calendarIdentifier = "calendar.identifier"
        static let calendarWeeksAhead = "calendar.weeksAhead"
        static let syncsHomeworkToCalendar = "calendar.homework"
        static let refreshesOnLaunch = "refresh.onLaunch"
        static let hidesDoneHomework = "homework.hideDone"
        static let notifiesHomework = "notify.homework"
        static let notifiesLowBalance = "notify.lowBalance"
    }

    /// `MensaModel` lives in the other half of the app and owns no `Settings`;
    /// it reads this one flag straight from `UserDefaults` under the same key
    /// the toggle above writes.
    static var lowBalanceNotificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.notifiesLowBalance)
    }
}
