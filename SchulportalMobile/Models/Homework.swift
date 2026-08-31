import Foundation

/// A single homework assignment as scraped from *Mein Unterricht*.
///
/// The portal only tells us the date of the lesson in which the homework was
/// **given** (that is what the userscript's digest note says). Some schools also
/// print an explicit due date inside the text — `dueDate` captures that when we
/// can find it, otherwise the UI falls back to `assignedDate`.
struct Homework: Identifiable, Codable, Hashable {
    /// Stable across refreshes: derived from the portal's own ids when present,
    /// otherwise from course + date + text.
    var id: String
    var courseID: String
    var courseTitle: String
    var subject: Subject
    var text: String
    /// Date of the lesson the homework was given in.
    var assignedDate: Date?
    /// Explicit deadline, parsed out of the text when the teacher wrote one.
    var dueDate: Date?
    /// What the portal itself thinks — `.done` renders as "erledigt".
    var isDoneOnPortal: Bool
    /// Ids needed to push the done-flag back to the portal, when available.
    var portalEntryID: String?
    var portalBookID: String?

    /// The date the UI sorts and groups by.
    var effectiveDate: Date? { dueDate ?? assignedDate }

    static func makeID(courseID: String, entryID: String?, date: Date?, text: String) -> String {
        // `data-entry` is a per-course counter (1, 2, 3, …), not a global id
        // — the portal's own POST scopes it with the book id, and two courses
        // both having "entry 3" is the norm. Unscoped, ticking one homework
        // could mark another course's homework done.
        if let entryID, !entryID.isEmpty { return "entry:\(courseID):\(entryID)" }
        let day = date.map { ISO8601DateFormatter.dayOnly.string(from: $0) } ?? "nodate"
        let digest = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        return "hash:" + StableHash.string("\(courseID)|\(day)|\(digest)")
    }
}

extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
