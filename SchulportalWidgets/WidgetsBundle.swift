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
    }
}

// MARK: - Provider

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
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

        let sorted = dates.sorted()
        let entries = sorted.map { SnapshotEntry(date: $0, snapshot: snapshot) }
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
