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
        var notifiesDigest: Bool
        var syncsEventsToCalendar: Bool
        var mensaTenantOverride: String
        /// `nil` = automatic: the tab is shown exactly when a tenant is known.
        var showsMensaTabOverride: Bool?
        var customLinks: [SchoolLink]
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
            notifiesLowBalance: defaults.object(forKey: Keys.notifiesLowBalance) as? Bool ?? false,
            notifiesDigest: defaults.object(forKey: Keys.notifiesDigest) as? Bool ?? false,
            syncsEventsToCalendar: defaults.object(forKey: Keys.syncsEventsToCalendar) as? Bool ?? false,
            mensaTenantOverride: defaults.string(forKey: Keys.mensaTenantOverride) ?? "",
            showsMensaTabOverride: defaults.object(forKey: Keys.showsMensaTab) as? Bool,
            customLinks: Self.decodeLinks(defaults.data(forKey: Keys.customLinks))
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

    var notifiesDigest: Bool {
        get { values.notifiesDigest }
        set { values.notifiesDigest = newValue; defaults.set(newValue, forKey: Keys.notifiesDigest) }
    }

    var syncsEventsToCalendar: Bool {
        get { values.syncsEventsToCalendar }
        set { values.syncsEventsToCalendar = newValue; defaults.set(newValue, forKey: Keys.syncsEventsToCalendar) }
    }

    // MARK: - Per-school configuration (registry + overrides)

    /// The bundled registry's entry for the configured school, if any.
    var registryConfig: SchoolConfig? {
        SchoolRegistry.entry(for: values.schoolID)
    }

    /// Empty means "use the registry"; anything else wins over it — for
    /// menuebestellung.de schools the registry does not know.
    var mensaTenantOverride: String {
        get { values.mensaTenantOverride }
        set { values.mensaTenantOverride = newValue; defaults.set(newValue, forKey: Keys.mensaTenantOverride) }
    }

    /// Override first, registry second, nothing third. `nil` means this
    /// school has no known caterer — and therefore no Essen tab.
    var effectiveMensaTenant: String? {
        let override = values.mensaTenantOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        return registryConfig?.mensaTenant
    }

    /// A school without a caterer must not carry a permanently dead tab, so
    /// the default follows the configuration; the user's explicit choice wins.
    var showsMensaTab: Bool {
        get { values.showsMensaTabOverride ?? (effectiveMensaTenant != nil) }
        set { values.showsMensaTabOverride = newValue; defaults.set(newValue, forKey: Keys.showsMensaTab) }
    }

    /// What the registry ships for this school, e.g. Elternbeirat and
    /// Förderverein pages for Eli.
    var registryLinks: [SchoolLink] {
        registryConfig?.links ?? []
    }

    /// Links the user added themselves (Hort, Schulwohnung, …).
    var customLinks: [SchoolLink] {
        get { values.customLinks }
        set {
            values.customLinks = newValue
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Keys.customLinks)
        }
    }

    private static func decodeLinks(_ data: Data?) -> [SchoolLink] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([SchoolLink].self, from: data)) ?? []
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
        static let notifiesDigest = "notify.digest"
        static let syncsEventsToCalendar = "calendar.events"
        static let mensaTenantOverride = "mensa.tenant"
        static let showsMensaTab = "mensa.showsTab"
        static let customLinks = "school.customLinks"
    }

    /// `MensaModel` lives in the other half of the app and owns no `Settings`;
    /// it reads this one flag straight from `UserDefaults` under the same key
    /// the toggle above writes.
    static var lowBalanceNotificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.notifiesLowBalance)
    }

    static var digestNotificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.notifiesDigest)
    }

    /// `MensaClient` builds its URLs off the main actor and owns no
    /// `Settings`, so the tenant resolution is repeated here straight from
    /// `UserDefaults` — same pattern as the notification flags above.
    static var storedMensaTenant: String? {
        let override = (UserDefaults.standard.string(forKey: Keys.mensaTenantOverride) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        let schoolID = UserDefaults.standard.string(forKey: Keys.schoolID) ?? ""
        return SchoolRegistry.entry(for: schoolID)?.mensaTenant
    }
}
