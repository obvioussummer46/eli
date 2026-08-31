import Foundation
import Observation
import OSLog

/// The single source of truth for the UI.
///
/// Local done-flags always win over what the portal reported, so ticking a
/// homework off feels instant and survives a failed or impossible round-trip.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case ready
    }

    private(set) var phase: Phase = .launching
    private(set) var snapshot = Snapshot()
    private(set) var isRefreshing = false
    private(set) var lastErrorMessage: String?
    /// Set when the portal rejected the session mid-refresh.
    private(set) var needsReauthentication = false
    /// Why the native sign-in failed — shown on the login screen.
    private(set) var signInErrorMessage: String?
    /// The account whose password is in the Keychain, when the user stored one.
    private(set) var portalUsername: String?

    let settings = Settings()

    private let service: PortalService
    private let store: SnapshotStore
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "model")

    init(service: PortalService = PortalService(), store: SnapshotStore = .shared) {
        self.service = service
        self.store = store
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        snapshot = await store.load()
        // `WKWebsiteDataStore` persists the portal's session cookie across
        // launches, `HTTPCookieStorage` does not — so the web view is what
        // carries the session over, and the scraper picks it up from there.
        await SPHCookies.importFromWebView()
        // Stored credentials are the other way back in: with them adopted,
        // `verifySession` signs in on its own when no cookie survived.
        let credentials = PortalKeychain.load()
        portalUsername = credentials?.username
        await service.adopt(credentials, schoolID: settings.schoolID)
        do {
            let signedIn = try await service.verifySession()
            phase = signedIn ? .ready : .signedOut
            needsReauthentication = !signedIn
            if signedIn, settings.refreshesOnLaunch {
                await refresh()
            }
        } catch SPHError.invalidCredentials(let detail) {
            await handleCredentialLoss(detail)
        } catch {
            phase = .signedOut
            needsReauthentication = true
        }
    }

    /// Called by the login screen once cookies are in place.
    func didSignIn() async {
        needsReauthentication = false
        signInErrorMessage = nil
        phase = .ready
        await refresh()
    }

    /// The native sign-in: verifies against the portal, then stores the
    /// credentials so the app can re-login silently — the mensa pattern.
    /// Needs the school picked, because the login form wants its number.
    func signIn(username: String, password: String) async -> Bool {
        signInErrorMessage = nil
        let credentials = PortalCredentials(username: username, password: password)
        do {
            try await service.signIn(credentials, schoolID: settings.schoolID)
        } catch {
            signInErrorMessage = error.localizedDescription
            return false
        }
        PortalKeychain.save(credentials)
        portalUsername = username
        await didSignIn()
        return true
    }

    func signOut() async {
        PortalKeychain.clear()
        portalUsername = nil
        await service.adopt(nil, schoolID: nil)
        await SPHCookies.clearAll()
        await store.reset()
        snapshot = Snapshot()
        phase = .signedOut
        needsReauthentication = true
    }

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        // Hoisted out of the child tasks so they capture a plain value rather
        // than a main-actor-isolated property.
        let service = self.service
        async let lessons = service.loadMeinUnterricht()
        async let plan = service.loadStundenplan()

        var errors: [String] = []

        do {
            let result = try await lessons
            apply(result)
        } catch SPHError.notLoggedIn {
            handleSessionLoss()
            return
        } catch SPHError.invalidCredentials(let detail) {
            await handleCredentialLoss(detail)
            return
        } catch {
            errors.append(error.localizedDescription)
        }

        do {
            snapshot.timetable = try await plan
        } catch SPHError.notLoggedIn {
            handleSessionLoss()
            return
        } catch SPHError.invalidCredentials(let detail) {
            await handleCredentialLoss(detail)
            return
        } catch {
            errors.append(error.localizedDescription)
        }

        snapshot.lastRefresh = Date()
        lastErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
        await persist()
        await retryPendingHomeworkSyncs()
    }

    private func handleSessionLoss() {
        needsReauthentication = true
        phase = .signedOut
        lastErrorMessage = SPHError.notLoggedIn.errorDescription
    }

    /// The portal rejected the stored *password*, not just the session.
    /// Keeping it would retry a wrong secret forever, so it is dropped and the
    /// login screen says why.
    private func handleCredentialLoss(_ detail: String) async {
        PortalKeychain.clear()
        portalUsername = nil
        await service.adopt(nil, schoolID: nil)
        signInErrorMessage = detail
        handleSessionLoss()
    }

    /// Merges a fresh scrape into the snapshot, keeping open homework the portal
    /// has already scrolled out of its two-week window.
    private func apply(_ result: MeinUnterrichtResult) {
        let previous = snapshot.entries.compactMap(\.homework) + snapshot.archivedHomework
        snapshot.courses = result.courses
        snapshot.entries = result.entries

        let currentIDs = Set(result.homework.map(\.id))
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast

        var archive: [String: Homework] = [:]
        for item in previous where !currentIDs.contains(item.id) {
            guard !isDone(item) else { continue }
            guard (item.effectiveDate ?? Date()) >= cutoff else { continue }
            archive[item.id] = item
        }
        snapshot.archivedHomework = archive.values.sorted { ($0.effectiveDate ?? .distantPast) > ($1.effectiveDate ?? .distantPast) }

        reconcileOverrides(with: result.homework)
    }

    /// Drops overrides the portal has caught up with, and lets a change made in
    /// the browser win over a local flag we already pushed.
    private func reconcileOverrides(with current: [Homework]) {
        let staleCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        for item in current {
            guard let override = snapshot.doneOverrides[item.id], override.syncedToPortal else { continue }
            // The portal has caught up — or it disagrees with a flag we pushed
            // long ago, which means it was changed in the browser since.
            if item.isDoneOnPortal == override.isDone || override.changedAt < staleCutoff {
                snapshot.doneOverrides.removeValue(forKey: item.id)
            }
        }
        // Forget overrides for homework nobody can see any more.
        let known = Set(current.map(\.id)).union(snapshot.archivedHomework.map(\.id))
        snapshot.doneOverrides = snapshot.doneOverrides.filter { known.contains($0.key) }
    }

    private func persist() async {
        let copy = snapshot
        await store.save(copy)
    }

    // MARK: - Homework

    var allHomework: [Homework] {
        let live = snapshot.entries.compactMap(\.homework)
        let liveIDs = Set(live.map(\.id))
        return live + snapshot.archivedHomework.filter { !liveIDs.contains($0.id) }
    }

    var openHomework: [Homework] {
        allHomework.filter { !isDone($0) }.sorted(by: Self.byDueDate)
    }

    var doneHomework: [Homework] {
        allHomework.filter { isDone($0) }.sorted(by: Self.byDueDate)
    }

    private static func byDueDate(_ lhs: Homework, _ rhs: Homework) -> Bool {
        let l = lhs.effectiveDate ?? .distantPast
        let r = rhs.effectiveDate ?? .distantPast
        if l == r { return lhs.subject.name < rhs.subject.name }
        return l > r
    }

    func isDone(_ homework: Homework) -> Bool {
        snapshot.doneOverrides[homework.id]?.isDone ?? homework.isDoneOnPortal
    }

    /// Whether the local flag is still waiting to reach the portal.
    func isPendingSync(_ homework: Homework) -> Bool {
        guard let override = snapshot.doneOverrides[homework.id] else { return false }
        return !override.syncedToPortal
    }

    func setDone(_ homework: Homework, _ done: Bool) {
        snapshot.doneOverrides[homework.id] = DoneOverride(isDone: done, changedAt: Date(), syncedToPortal: false)
        Task { await persist() }
        Task { await pushDoneFlag(for: homework, done: done) }
    }

    func toggleDone(_ homework: Homework) {
        setDone(homework, !isDone(homework))
    }

    private func pushDoneFlag(for homework: Homework, done: Bool) async {
        do {
            let outcome = try await service.setHomeworkDone(homework, done: done)
            if outcome == .localOnly {
                logger.notice("Das Portal kennt kein Zurücknehmen — der Haken bleibt lokal.")
            }
            // `.localOnly` counts as settled: there is nothing left to send, so
            // the entry must not sit in the retry queue.
            markSettled(homework, done: done)
            await persist()
        } catch SPHError.notSupported {
            // Missing ids or a portal that refuses the POST: no retry will
            // ever change that, so the tick settles as local-only. Leaving it
            // "pending" would show a "wird erneut versucht" that never comes
            // true — and retry a hopeless request on every refresh.
            logger.notice("Das Portal nimmt diesen Haken nicht an — er bleibt lokal.")
            markSettled(homework, done: done)
            await persist()
        } catch {
            // Local state stands; we retry on the next refresh.
            logger.notice("Hausaufgabe konnte nicht ans Portal gemeldet werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func markSettled(_ homework: Homework, done: Bool) {
        guard var override = snapshot.doneOverrides[homework.id], override.isDone == done else { return }
        override.syncedToPortal = true
        snapshot.doneOverrides[homework.id] = override
    }

    private func retryPendingHomeworkSyncs() async {
        let pending = snapshot.doneOverrides.filter { !$0.value.syncedToPortal }
        guard !pending.isEmpty else { return }
        let lookup = Dictionary(allHomework.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (id, override) in pending {
            guard let homework = lookup[id] else { continue }
            await pushDoneFlag(for: homework, done: override.isDone)
        }
    }

    // MARK: - Today

    var today: Weekday? {
        Weekday.fromCalendarWeekday(GermanDate.calendar.component(.weekday, from: Date()))
    }

    var todaysLessons: [TimetableEntry] {
        guard let today else { return [] }
        return snapshot.timetable.entries(on: today)
    }

    /// The lesson happening right now, or the next one today.
    var currentOrNextLesson: TimetableEntry? {
        let now = GermanDate.calendar.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let lessons = todaysLessons
        if let ongoing = lessons.first(where: { $0.start.minutesFromMidnight <= minutes && minutes < $0.end.minutesFromMidnight }) {
            return ongoing
        }
        return lessons.first { $0.start.minutesFromMidnight > minutes }
    }
}
