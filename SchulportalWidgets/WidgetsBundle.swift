import SwiftUI
import WidgetKit

/// The widgets are the app for someone who never opens the app: next lesson,
/// the day at a glance, the lunch balance. Everything renders offline from
/// the `SharedSnapshot` the app writes — a widget never talks to the portal.
@main
struct SchulportalWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextLessonWidget()
        TodayWidget()
        MensaWidget()
        // Premium — widget pack or Pro. Locked, each renders a placeholder
        // that opens the paywall, never an empty tile.
        HomeworkWidget()
        DayPlanWidget()
        CountdownWidget()
        LessonLiveActivity()
    }
}

// MARK: - Provider

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
    /// Whether the premium widgets may show their content. The gallery and
    /// the placeholder always say yes — a locked preview sells nothing.
    var unlocksPremium = true
}

/// One provider for all three widgets: entries at every lesson boundary of
/// the current day plus the midnight rollover, so "Nächste Stunde" ticks
/// forward without any background work of its own.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: SharedSnapshotStore.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = SharedSnapshotStore.load()
        let cal = SharedSnapshot.calendar
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)

        var dates: Set<Date> = [now]
        for lesson in snapshot?.lessons(on: now) ?? [] {
            for minutes in [lesson.startMinutes, lesson.endMinutes] {
                if let boundary = cal.date(byAdding: .minute, value: minutes, to: startOfDay), boundary > now {
                    dates.insert(boundary)
                }
            }
        }
        if let rollover = cal.date(byAdding: .day, value: 1, to: startOfDay) {
            dates.insert(rollover.addingTimeInterval(60))
        }

        let unlocked = EntitlementStore.load().unlocksPremiumWidgets
        let sorted = dates.sorted()
        let entries = sorted.map { SnapshotEntry(date: $0, snapshot: snapshot, unlocksPremium: unlocked) }
        completion(Timeline(entries: entries, policy: .after(sorted.last ?? now.addingTimeInterval(3600))))
    }
}

// MARK: - Shared bits

extension SharedSnapshot {
    /// What the widget gallery shows before the app ever wrote a snapshot.
    static let preview: SharedSnapshot = {
        var snapshot = SharedSnapshot()
        snapshot.weekdayLessons = [1: [
            SharedLesson(startMinutes: 8 * 60 + 10, endMinutes: 9 * 60 + 40, subject: "Mathematik", room: "2.16", colorHex: "#0040dd"),
            SharedLesson(startMinutes: 10 * 60, endMinutes: 11 * 60 + 30, subject: "Deutsch", room: "2.16", colorHex: "#d70015"),
            SharedLesson(startMinutes: 11 * 60 + 50, endMinutes: 13 * 60 + 20, subject: "Englisch", room: "1.02", colorHex: "#248a3d")
        ]]
        snapshot.balanceText = "25,85 €"
        let cal = SharedSnapshot.calendar
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        snapshot.homework = [
            SharedHomework(id: "preview-1", subject: "Mathematik", colorHex: "#0040dd", text: "S. 42, Nr. 3–7", deadline: tomorrow),
            SharedHomework(id: "preview-2", subject: "Englisch", colorHex: "#248a3d", text: "Vokabeln Unit 3 lernen", deadline: tomorrow),
            SharedHomework(id: "preview-3", subject: "Deutsch", colorHex: "#d70015", text: "Lesetagebuch Kapitel 4", deadline: cal.date(byAdding: .day, value: 3, to: Date()))
        ]
        snapshot.events = [
            SharedEvent(id: "preview-e1", title: "Mathe-Arbeit", start: cal.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                        end: cal.date(byAdding: .day, value: 5, to: Date()) ?? Date(), isAllDay: true, isExam: true, isHoliday: false, colorHex: "#d70015"),
            SharedEvent(id: "preview-e2", title: "Herbstferien", start: cal.date(byAdding: .day, value: 23, to: Date()) ?? Date(),
                        end: cal.date(byAdding: .day, value: 37, to: Date()) ?? Date(), isAllDay: true, isExam: false, isHoliday: true, colorHex: "#248a3d")
        ]
        return snapshot
    }()
}

enum WidgetFormat {
    static let weekdayDayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = SharedSnapshot.calendar.timeZone
        formatter.dateFormat = "EE, d.M."
        return formatter
    }()

    /// "Mo.", "Di." — for day labels past tomorrow.
    static let weekdayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = SharedSnapshot.calendar.timeZone
        formatter.dateFormat = "EE"
        return formatter
    }()
}

/// The line every widget falls back to when the app has not written a
/// snapshot yet (first run, or a build without the App Group).
struct OpenAppHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "graduationcap")
                .foregroundStyle(.secondary)
            Text("App öffnen,\num Daten zu laden")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
