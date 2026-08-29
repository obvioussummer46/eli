import Foundation
import Observation
import OSLog

/// State for the „Essen“ tab.
///
/// Kept apart from `AppModel` on purpose: this is a different service, a
/// different account and a different session, and nothing about the mensa
/// should be able to break a Schulportal refresh (or the other way round).
///
/// Nothing is persisted to disk. The plan changes weekly and the balance
/// changes hourly, so a stale cached copy would be worse than an empty screen —
/// and the balance is the one number nobody should read out of date.
@MainActor
@Observable
final class MensaModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case ready
    }

    private(set) var phase: Phase = .launching
    private(set) var account = MensaAccount()
    private(set) var week = MenuWeek()
    private(set) var statement = MensaStatement()
    private(set) var isLoading = false
    /// A failure of the plan page — the tab's actual content. Worth a banner.
    private(set) var weekErrorMessage: String?
    /// A failure of the account statement. Deliberately *not* worth a banner:
    /// see `refresh()`.
    private(set) var statementErrorMessage: String?
    private(set) var lastRefresh: Date?
    /// Set when the stored credentials stopped working — the login screen says
    /// so instead of silently showing nothing.
    private(set) var signInErrorMessage: String?

    /// `nil` means "whatever week the site thinks is current".
    private(set) var selectedWeekKey: String?

    private let service: MensaService
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "mensa")

    init(service: MensaService = MensaService()) {
        self.service = service
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard let credentials = MensaKeychain.load() else {
            phase = .signedOut
            return
        }
        account.username = credentials.username
        await service.adopt(credentials)
        phase = .ready
        await refresh()
    }

    /// From the login screen. Verifies against the site *before* storing, so a
    /// typo never ends up in the Keychain.
    func signIn(username: String, password: String) async -> Bool {
        signInErrorMessage = nil
        isLoading = true

        let credentials = MensaCredentials(username: username, password: password)
        do {
            try await service.signIn(credentials)
        } catch {
            signInErrorMessage = error.localizedDescription
            isLoading = false
            return false
        }

        MensaKeychain.save(credentials)
        account.username = username
        phase = .ready
        // Cleared before the refresh, not after: `refresh()` bails out while a
        // load is already running, and this one has to go through.
        isLoading = false
        await refresh()
        return true
    }

    func signOut() async {
        MensaKeychain.clear()
        await service.signOut()
        account = MensaAccount()
        week = MenuWeek()
        statement = MensaStatement()
        selectedWeekKey = nil
        lastRefresh = nil
        weekErrorMessage = nil
        statementErrorMessage = nil
        phase = .signedOut
    }

    // MARK: - Refresh

    func refresh() async {
        guard phase == .ready, !isLoading else { return }
        isLoading = true
        weekErrorMessage = nil
        statementErrorMessage = nil
        defer { isLoading = false }

        do {
            // The plan page carries the balance in its sidebar, so this alone
            // is enough to fill the screen; the statement is the extra detail.
            let result = try await service.loadWeek(selectedWeekKey)
            week = result.week
            selectedWeekKey = result.week.key.isEmpty ? selectedWeekKey : result.week.key
            account.username = result.account.username.isEmpty ? account.username : result.account.username
            account.balanceText = result.account.balanceText
            account.balance = result.account.balance
        } catch {
            if handleSignInFailure(error) { return }
            weekErrorMessage = error.localizedDescription
        }

        do {
            statement = try await service.loadStatement()
            // The API is the more precise of the two sources; let it win.
            if let balance = statement.balance {
                account.balance = balance
                account.balanceText = statement.balanceText
            }
        } catch {
            if handleSignInFailure(error) { return }
            // The statement is the tab's footnote, not its point: the balance
            // and the whole week's menu come from the plan page and are already
            // on screen. Putting a warning across a screen that is otherwise
            // correct — and that the user can do nothing about — only teaches
            // them to ignore warnings, so this one stays inside the Kontoauszug
            // where it means something.
            statementErrorMessage = error.localizedDescription
            logger.notice("Kontoauszug nicht geladen: \(error.localizedDescription, privacy: .public)")
        }

        lastRefresh = Date()
    }

    /// Only a rejected *credential* sends the user back to the login screen. A
    /// dropped session is the client's problem and it re-logs in by itself, so
    /// it must never surface here.
    private func handleSignInFailure(_ error: Error) -> Bool {
        switch error {
        case MensaError.invalidCredentials(let detail):
            signInErrorMessage = detail
        case MensaError.secondFactorRequired:
            signInErrorMessage = MensaError.secondFactorRequired.errorDescription
        case MensaError.noCredentials:
            signInErrorMessage = nil
        default:
            return false
        }
        logger.notice("Zugangsdaten fürs Bestellsystem abgelehnt, zurück zur Anmeldung.")
        MensaKeychain.clear()
        phase = .signedOut
        return true
    }

    // MARK: - Week navigation

    func selectWeek(_ key: String) async {
        guard key != week.key else { return }
        selectedWeekKey = key
        await refresh()
    }

    var previousWeek: WeekOption? {
        guard let index = weekIndex, index > 0 else { return nil }
        return week.availableWeeks[index - 1]
    }

    var nextWeek: WeekOption? {
        guard let index = weekIndex, index + 1 < week.availableWeeks.count else { return nil }
        return week.availableWeeks[index + 1]
    }

    private var weekIndex: Int? {
        week.availableWeeks.firstIndex { $0.key == week.key }
    }

    // MARK: - Today

    /// The day of the shown week that matches today, if the week contains it.
    var todaysDay: MenuDay? {
        let today = GermanDate.calendar.startOfDay(for: Date())
        return week.days.first { day in
            guard let date = day.date else { return false }
            return GermanDate.calendar.startOfDay(for: date) == today
        }
    }

    /// What to open the day picker on: today, else the first day that is still
    /// open, else Monday.
    var defaultDayID: String? {
        todaysDay?.id ?? week.days.first { !$0.isLocked }?.id ?? week.days.first?.id
    }
}
