import Foundation
import SwiftSoup

struct MeinUnterrichtResult: Equatable {
    var courses: [Course] = []
    var entries: [LessonEntry] = []

    var homework: [Homework] { entries.compactMap(\.homework) }
}

/// Scrapes `meinunterricht.php`.
///
/// The markup we rely on is exactly what the userscript already targets:
/// `tr[data-book]` rows carrying `.name`, `b.thema`, `span.datum`, `.inhalt`
/// and `.homework > .realHomework` / `.homework > .done`.
enum MeinUnterrichtParser {
    static func parse(html: String, reference: Date = Date()) throws -> MeinUnterrichtResult {
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw SPHError.parsing("Mein Unterricht")
        }

        var result = MeinUnterrichtResult()
        var coursesByID: [String: Course] = [:]

        for row in document.allMatches("tr[data-book]") {
            guard let entry = parseRow(row, reference: reference) else { continue }
            result.entries.append(entry)
            if coursesByID[entry.courseID] == nil {
                coursesByID[entry.courseID] = Course(id: entry.courseID,
                                                     rawTitle: entry.courseTitle,
                                                     subject: entry.subject,
                                                     teacher: teacher(in: row))
            }
        }

        // The "Kurse" box lists courses that currently have no entries.
        for link in document.allMatches("a[href*=sus_view]") {
            guard let href = link.attribute("href"),
                  let id = courseID(fromHref: href) else { continue }
            let title = HTMLText.inline(link)
            guard !title.isEmpty, title.count < 80 else { continue }
            if coursesByID[id] == nil {
                coursesByID[id] = Course(id: id,
                                         rawTitle: title,
                                         subject: Subject.resolve(fromCourseTitle: title),
                                         teacher: nil)
            }
        }

        result.courses = coursesByID.values.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        result.entries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        if result.entries.isEmpty && result.courses.isEmpty {
            throw SPHError.emptyPage("Mein Unterricht")
        }
        return result
    }

    // MARK: - Row

    private static func parseRow(_ row: Element, reference: Date) -> LessonEntry? {
        let bookID = row.attribute("data-book")
        let entryID = row.attribute("data-entry") ?? row.firstMatch("[data-entry]")?.attribute("data-entry")

        let nameElement = row.firstMatch(".name") ?? row.firstMatch("h3 a") ?? row.firstMatch("h3")
        let courseTitle = HTMLText.inline(nameElement)
        guard !courseTitle.isEmpty else { return nil }

        let href = row.firstMatch("a[href*=sus_view]")?.attribute("href")
        let courseID = href.flatMap(courseID(fromHref:)) ?? bookID ?? StableHash.string(courseTitle)

        let subject = Subject.resolve(fromCourseTitle: courseTitle)
        let topic = HTMLText.inline(row.firstMatch("b.thema") ?? row.firstMatch(".thema"))
        let dateText = HTMLText.inline(row.firstMatch("span.datum") ?? row.firstMatch(".datum"))
        let date = GermanDate.firstDate(in: dateText, reference: reference)
        let content = HTMLText.multiline(row.firstMatch(".inhalt"))

        let homework = parseHomework(in: row,
                                     courseID: courseID,
                                     courseTitle: courseTitle,
                                     subject: subject,
                                     date: date,
                                     entryID: entryID,
                                     bookID: bookID,
                                     reference: reference)

        let attachments = parseAttachments(in: row)

        // Course-scoped for the same reason as `Homework.makeID`: `data-entry`
        // counts per book, so "entry 3" exists in every course.
        let id = entryID.map { "entry:\(courseID):\($0)" }
            ?? "row:" + StableHash.string("\(courseID)|\(dateText)|\(topic)")

        return LessonEntry(id: id,
                           courseID: courseID,
                           courseTitle: courseTitle,
                           subject: subject,
                           date: date,
                           topic: topic.isEmpty ? nil : topic,
                           content: content.isEmpty ? nil : content,
                           homework: homework,
                           attachments: attachments)
    }

    private static func parseHomework(in row: Element,
                                      courseID: String,
                                      courseTitle: String,
                                      subject: Subject,
                                      date: Date?,
                                      entryID: String?,
                                      bookID: String?,
                                      reference: Date) -> Homework? {
        guard let container = row.firstMatch(".homework") else { return nil }
        let text = HTMLText.multiline(container.firstMatch(".realHomework"))
        guard !text.isEmpty else { return nil }

        let isDone = doneState(in: container)
        return Homework(id: Homework.makeID(courseID: courseID, entryID: entryID, date: date, text: text),
                        courseID: courseID,
                        courseTitle: courseTitle,
                        subject: subject,
                        text: text,
                        assignedDate: date,
                        dueDate: GermanDate.dueDate(in: text, reference: date ?? reference),
                        isDoneOnPortal: isDone,
                        portalEntryID: entryID,
                        portalBookID: bookID)
    }

    /// Two views of the same flag, depending on who is looking.
    ///
    /// **Pupil view:** the portal ships *both* labels on every entry and
    /// switches between them with the `hidden` class — `.done` ("erledigt")
    /// carries `hidden` while the homework is still open, and `.undone` (the
    /// "als erledigt markieren" button) is the one on screen. Its own
    /// `sus_start.js` does exactly this: on a successful tick it calls
    /// `.done` `removeClass('hidden')` and fades `.undone` out. The label
    /// text says nothing there; no pupil label ever reads "offen".
    ///
    /// **Parent view:** no `.undone` button at all, and `.done` is an
    /// always-visible status label whose *text* is the state — "offen" on
    /// `label-warning`, "erledigt" on `label-success`. Reading the pupil
    /// rule against it would tick off every single homework.
    private static func doneState(in container: Element) -> Bool {
        if let done = container.firstMatch(".done") {
            if hasClass(done, "hidden") { return false }
            let text = HTMLText.inline(done).lowercased()
            if text.contains("offen") { return false }
            return true
        }
        if let undone = container.firstMatch(".undone") {
            return hasClass(undone, "hidden")
        }
        return false
    }

    /// Whole-token class test. Substring matching is not safe here: the portal
    /// also uses `hidden-print`, which would otherwise read as `hidden`.
    private static func hasClass(_ element: Element, _ name: String) -> Bool {
        guard let classes = try? element.className() else { return false }
        return classes.split(whereSeparator: \.isWhitespace)
            .contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func parseAttachments(in row: Element) -> [Attachment] {
        var seen = Set<String>()
        return row.allMatches("a[href*=sus_download]").compactMap { link -> Attachment? in
            guard let href = link.attribute("href"),
                  let url = URL(string: href, relativeTo: SPHEndpoints.base)?.absoluteURL,
                  seen.insert(url.absoluteString).inserted else { return nil }
            var name = HTMLText.inline(link)
            if name.isEmpty { name = link.attribute("title") ?? "Anhang" }
            return Attachment(name: name, url: url)
        }
    }

    private static func teacher(in row: Element) -> String? {
        let element = row.firstMatch(".teacher .btn") ?? row.firstMatch(".teacher")
        let value = HTMLText.inline(element)
        return value.isEmpty ? nil : value
    }

    /// `meinunterricht.php?a=sus_view&id=12345`
    static func courseID(fromHref href: String) -> String? {
        guard let url = URL(string: href, relativeTo: SPHEndpoints.base) else { return nil }
        return url.queryValues["id"]
    }
}
