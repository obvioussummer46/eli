import SwiftUI
import UIKit

/// Open homework as a file to share: plain text for a message to a parent,
/// CSV for whoever keeps a spreadsheet. Pro feature — small, self-contained,
/// and nobody needs it to do their homework.
enum HomeworkExport {
    enum Format: String, CaseIterable, Identifiable {
        case text, csv

        var id: String { rawValue }
        var title: String { self == .text ? "Als Text" : "Als Tabelle (CSV)" }
        var systemImage: String { self == .text ? "doc.text" : "tablecells" }
        var fileExtension: String { self == .text ? "txt" : "csv" }
    }

    /// Writes the export into the temporary directory and hands back the
    /// URL for the share sheet. `nil` only when the disk refuses.
    @MainActor
    static func file(_ format: Format, items: [Homework], model: AppModel) -> URL? {
        let contents: String
        switch format {
        case .text: contents = text(items, model: model)
        case .csv: contents = csv(items, model: model)
        }
        let stamp = ISO8601DateFormatter.dayOnly.string(from: Date())
        let url = URL.temporaryDirectory.appendingPathComponent("Hausaufgaben-\(stamp).\(format.fileExtension)")
        do {
            try Data(contents.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    static func text(_ items: [Homework], model: AppModel) -> String {
        var lines = ["Hausaufgaben, Stand \(GermanDate.dayMonthYear.string(from: Date()))", ""]
        var lastDay: String?
        for item in items {
            let deadline = model.deadline(for: item)
            let day = deadline.map { GermanDate.weekdayDayMonth.string(from: $0) } ?? "Ohne Termin"
            if day != lastDay {
                if lastDay != nil { lines.append("") }
                lines.append(day)
                lastDay = day
            }
            let mark = model.isDone(item) ? "☑" : "☐"
            lines.append("\(mark) \(item.subject.name): \(item.text.replacingOccurrences(of: "\n", with: " "))")
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func csv(_ items: [Homework], model: AppModel) -> String {
        var rows = ["Fällig;Fach;Kurs;Aufgabe;Aufgegeben;Erledigt"]
        for item in items {
            let deadline = model.deadline(for: item).map { GermanDate.dayMonthYear.string(from: $0) } ?? ""
            let assigned = item.assignedDate.map { GermanDate.dayMonthYear.string(from: $0) } ?? ""
            rows.append([
                deadline,
                item.subject.name,
                item.courseTitle,
                item.text,
                assigned,
                model.isDone(item) ? "ja" : "nein"
            ].map(quote).joined(separator: ";"))
        }
        // BOM so Excel on Windows reads the umlauts; semicolons because
        // German Excel splits on them, not on commas.
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    private static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// The system share sheet, for a file URL.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// `.sheet(item:)` wants an `Identifiable`; a URL is identified by itself.
struct ShareFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
