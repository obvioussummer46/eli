import Foundation
import OSLog
import SwiftSoup

/// The portal pages the app fetches natively, by the filename their links
/// carry on the Startseite.
enum PortalModule: String, CaseIterable, Sendable {
    case meinUnterricht = "meinunterricht.php"
    case stundenplan = "stundenplan.php"
    case vertretungsplan = "vertretungsplan.php"
    case kalender = "kalender.php"
}

/// What actually became of a done-flag push.
enum HomeworkPushOutcome {
    /// The portal confirmed the tick.
    case pushed
    /// Nothing was sent, and nothing can be: the portal has no un-tick route,
    /// so the change only ever lives locally. Not an error, not worth retrying.
    case localOnly
}

/// Fetch + parse, one method per portal page.
struct PortalService {
    private let client: SPHClient
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "portal")

    init(client: SPHClient = .shared) {
        self.client = client
    }

    // MARK: - Session

    /// Verifies against the portal *before* anything is stored — a typo must
    /// never end up in the Keychain.
    func signIn(_ credentials: PortalCredentials, schoolID: String) async throws {
        try await client.signIn(credentials, schoolID: schoolID)
    }

    func adopt(_ credentials: PortalCredentials?, schoolID: String?) async {
        await client.adopt(credentials, schoolID: schoolID)
    }

    /// Which portal pages this account can see at all. The Startseite links
    /// every enabled module; an Eltern-Konto typically lacks „Mein
    /// Unterricht“ and often the Stundenplan, and asking for a page the
    /// account does not have only turns "this account cannot see homework"
    /// into a parser error.
    func loadAvailableModules() async throws -> Set<PortalModule> {
        let html = try await client.html(SPHEndpoints.startseite)
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw SPHError.parsing("Die Startseite")
        }
        var modules: Set<PortalModule> = []
        for module in PortalModule.allCases {
            if document.firstMatch("a[href*=\(module.rawValue)]") != nil {
                modules.insert(module)
            }
        }
        // A startseite that links nothing recognisable is markup we do not
        // understand — claiming "this account has no modules" from it would
        // switch the whole app off over a redesign.
        guard !modules.isEmpty else { throw SPHError.parsing("Die Startseite") }
        return modules
    }

    func loadMeinUnterricht() async throws -> MeinUnterrichtResult {
        let html = try await client.html(SPHEndpoints.meinUnterricht)
        return try MeinUnterrichtParser.parse(html: html)
    }

    func loadStundenplan() async throws -> Timetable {
        let html = try await client.html(SPHEndpoints.stundenplan)
        return try StundenplanParser.parse(html: html)
    }

    /// The Vertretungsplan. The page is a shell whose day buttons carry
    /// `data-tag` dates; each day is then fetched as JSON the way the page's
    /// own script does it. Shells without the AJAX interface (schools that
    /// disable full-plan access) fall back to their server-rendered tables.
    func loadVertretungsplan() async throws -> SubstitutionPlan {
        let shell = try await client.html(SPHEndpoints.vertretungsplan)
        let dates = VertretungsplanParser.dates(inShell: shell)
        guard !dates.isEmpty else {
            return try VertretungsplanParser.plan(fromShell: shell)
        }

        // The day's Hinweise only ever live in the shell, whichever way the
        // rows arrive.
        let infosByDate = VertretungsplanParser.infos(inShell: shell)

        var plan = SubstitutionPlan()
        for date in dates {
            let body = try await client.postForm(SPHEndpoints.vertretungsplan.appendingQuery(["a": "my"]),
                                                 fields: ["tag": date, "ganzerPlan": "true"])
            guard let data = body.data(using: .utf8) else { continue }
            do {
                var day = try VertretungsplanParser.day(fromAJAX: data, date: date)
                day.infos = infosByDate[date]
                plan.days.append(day)
            } catch {
                // One unreadable day means the AJAX contract is off for this
                // school — the tables are then the honest source for all days.
                return try VertretungsplanParser.plan(fromShell: shell)
            }
        }
        plan.fetchedAt = Date()
        return plan
    }

    /// The school calendar for a window around now: a week back (running
    /// events count) to four months out. `?f=getEvents` answers with plain
    /// JSON; only the category names and colours come from the page itself.
    func loadKalender() async throws -> [SchoolEvent] {
        let shell = try await client.html(SPHEndpoints.kalender)
        let categories = KalenderParser.categories(inShell: shell)

        let now = Date()
        let cal = GermanDate.calendar
        let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let end = cal.date(byAdding: .day, value: 120, to: now) ?? now
        let body = try await client.postForm(SPHEndpoints.kalender.appendingQuery(["f": "getEvents"]), fields: [
            "f": "getEvents",
            "start": Self.isoDay.string(from: start),
            "end": Self.isoDay.string(from: end),
            "s": ""
        ])
        guard let data = body.data(using: .utf8) else { throw SPHError.parsing("Der Kalender") }
        return try KalenderParser.events(fromJSON: data, categories: categories)
    }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Pushes the done-flag back to the portal so the change is visible in the
    /// browser and to teachers.
    ///
    /// The portal exposes this as a small form POST on `meinunterricht.php`;
    /// it answers with `1` on success. When the ids are missing (older markup,
    /// or an entry the portal did not tag) there is nothing to push and the
    /// change stays local — which is why `AppModel` treats the local override
    /// as the source of truth for the UI.
    ///
    /// The payload is exactly the one the portal's own `sus_start.js` sends:
    /// `a`, `id` and `entry`, and nothing else.
    @discardableResult
    func setHomeworkDone(_ homework: Homework, done: Bool) async throws -> HomeworkPushOutcome {
        guard let entryID = homework.portalEntryID, let bookID = homework.portalBookID else {
            throw SPHError.notSupported("Diese Hausaufgabe lässt sich im Portal nicht abhaken.")
        }
        // The portal is one-way: `sus_start.js` binds the POST to the "als
        // erledigt markieren" button and offers no route back. Un-ticking is
        // therefore local-only — reporting it as a failure would leave the
        // entry pending and retried on every refresh, forever.
        guard done else { return .localOnly }

        let body = try await client.postForm(SPHEndpoints.meinUnterricht, fields: [
            "a": "sus_homeworkDone",
            "entry": entryID,
            "id": bookID
        ])
        let answer = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer == "1" || answer.lowercased().contains("true") || answer.isEmpty else {
            logger.warning("Unerwartete Antwort auf sus_homeworkDone: \(answer.prefix(120), privacy: .public)")
            throw SPHError.notSupported("Das Schulportal hat den Haken nicht bestätigt.")
        }
        return .pushed
    }

    func verifySession() async throws -> Bool {
        try await client.verifySession()
    }
}
