import Foundation

/// One course ("Kurs") from *Mein Unterricht*.
struct Course: Identifiable, Codable, Hashable {
    /// The `id` query parameter of `meinunterricht.php?a=sus_view&id=…`.
    /// Falls back to the raw title when the portal does not expose one.
    var id: String
    /// Title exactly as printed by the portal, e.g. `"M 07c GYM"`.
    var rawTitle: String
    var subject: Subject
    var teacher: String?

    var displayName: String { subject.name }
    /// Short suffix shown next to the big subject name (the `<small>` in the userscript).
    var detailSuffix: String? { rawTitle == subject.name ? nil : rawTitle }
}

/// One row of the "Aktuelle Einträge" table: a single lesson with its topic,
/// optional lesson content and optional homework.
struct LessonEntry: Identifiable, Codable, Hashable {
    var id: String
    var courseID: String
    var courseTitle: String
    var subject: Subject
    /// The date of the lesson the entry belongs to.
    var date: Date?
    var topic: String?
    /// The expandable "Inhalt" block.
    var content: String?
    var homework: Homework?
    var attachments: [Attachment]
}

struct Attachment: Identifiable, Codable, Hashable {
    var id: String { url.absoluteString }
    var name: String
    var url: URL
}
