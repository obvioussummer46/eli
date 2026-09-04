import AppIntents
import Foundation

/// "Hey Siri, was habe ich morgen?" — one sentence from the same snapshot
/// the widgets and the evening digest read, so it works with the app
/// closed and offline. Pro: the free app answers with a pointer instead.
struct TomorrowIntent: AppIntent {
    static var title: LocalizedStringResource { "Was habe ich morgen?" }
    static var description: IntentDescription {
        IntentDescription("Stunden, fällige Aufgaben und Vertretungen für den nächsten Schultag.")
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard EntitlementStore.load().isPro else {
            return .result(dialog: "Die Siri-Abfrage ist Teil von \(Brand.pro). Freischalten unter Mehr in der App.")
        }
        guard let snapshot = SharedSnapshotStore.load() else {
            return .result(dialog: "Bitte öffne die App einmal, damit ich deinen Plan kenne.")
        }
        let cal = SharedSnapshot.calendar
        let now = Date()
        guard let day = snapshot.nextSchoolDay(after: now) else {
            return .result(dialog: "In den nächsten Tagen stehen keine Stunden im Plan. Schulfrei!")
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let dayName = cal.isDate(day, inSameDayAs: tomorrow) ? "Morgen" : "Am \(Self.weekday.string(from: day))"

        let lessons = snapshot.lessons(on: day)
        let due = snapshot.deadlineSubjects(on: day)
        let substitutions = snapshot.substitutions(on: day)

        var parts: [String] = []
        if let first = lessons.first, let last = lessons.last {
            parts.append("\(lessons.count) Stunden von \(first.startLabel) bis \(last.endLabel), zuerst \(first.subject)")
        }
        parts.append(due.isEmpty ? "keine fälligen Aufgaben" : "fällig: \(due.joined(separator: ", "))")
        if !substitutions.isEmpty {
            parts.append("\(substitutions.count) Vertretung\(substitutions.count == 1 ? "" : "en")")
        }
        if let dish = snapshot.orderedDish(on: day) {
            parts.append("Essen: \(dish)")
        }
        return .result(dialog: IntentDialog(stringLiteral: "\(dayName): " + parts.joined(separator: ". ") + "."))
    }

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = SharedSnapshot.calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

/// Registers the phrases Siri and the Shortcuts app offer without setup.
struct SchulportalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TomorrowIntent(),
            phrases: [
                "Was habe ich morgen in \(.applicationName)",
                "Morgen in \(.applicationName)",
                "\(.applicationName) Stundenplan für morgen"
            ],
            shortTitle: "Morgen",
            systemImageName: "sun.horizon"
        )
    }
}
