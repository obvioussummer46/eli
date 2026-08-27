import Foundation
import OSLog

/// Fetch + parse, one method per portal page.
struct PortalService {
    private let client: SPHClient
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "portal")

    init(client: SPHClient = .shared) {
        self.client = client
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
    func setHomeworkDone(_ homework: Homework, done: Bool) async throws {
        guard let entryID = homework.portalEntryID, let bookID = homework.portalBookID else {
            throw SPHError.notSupported("Diese Hausaufgabe lässt sich im Portal nicht abhaken.")
        }
        let body = try await client.postForm(SPHEndpoints.meinUnterricht, fields: [
            "a": "sus_homeworkDone",
            "entry": entryID,
            "id": bookID,
            "b": done ? "done" : "undone"
        ])
        let answer = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer == "1" || answer.lowercased().contains("true") || answer.isEmpty else {
            logger.warning("Unerwartete Antwort auf sus_homeworkDone: \(answer.prefix(120), privacy: .public)")
            throw SPHError.notSupported("Das Schulportal hat den Haken nicht bestätigt.")
        }
    }

    func verifySession() async -> Bool {
        await client.verifySession()
    }
}
