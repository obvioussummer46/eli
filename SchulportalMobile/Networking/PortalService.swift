import Foundation
import OSLog

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

    func loadMeinUnterricht() async throws -> MeinUnterrichtResult {
        let html = try await client.html(SPHEndpoints.meinUnterricht)
        return try MeinUnterrichtParser.parse(html: html)
    }

    func loadStundenplan() async throws -> Timetable {
        let html = try await client.html(SPHEndpoints.stundenplan)
        return try StundenplanParser.parse(html: html)
    }

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
