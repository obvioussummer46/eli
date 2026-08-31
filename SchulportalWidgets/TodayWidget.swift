import SwiftUI
import WidgetKit

/// The day at a glance: the remaining lessons, plus the two things worth a
/// warning colour — Vertretungen and homework due tomorrow.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: SnapshotProvider()) { entry in
            TodayView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Heute")
        .description("Die nächsten Stunden, Vertretungen und fällige Aufgaben.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            OpenAppHint()
        }
    }

    private func content(_ snapshot: SharedSnapshot) -> some View {
        let cal = SharedSnapshot.calendar
        let now = entry.date
        // After the last lesson the interesting day is tomorrow.
        let todaysRemaining = remainingLessons(snapshot, at: now)
        let showingTomorrow = todaysRemaining.isEmpty
        let day = showingTomorrow ? (cal.date(byAdding: .day, value: 1, to: now) ?? now) : now
        let lessons = showingTomorrow ? Array(snapshot.lessons(on: day).prefix(3)) : todaysRemaining
        let substitutions = snapshot.substitutions(on: day)
        let dueTomorrow = snapshot.deadlineSubjects(on: cal.date(byAdding: .day, value: 1, to: now) ?? now)

        return VStack(alignment: .leading, spacing: 6) {
            Text(showingTomorrow
                 ? "Morgen · \(WidgetFormat.weekdayDayMonth.string(from: day))"
                 : "Heute · \(WidgetFormat.weekdayDayMonth.string(from: day))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if lessons.isEmpty {
                Text("Keine Stunden — schulfrei 🎉")
                    .font(.subheadline)
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(lessons, id: \.self) { lesson in
                    HStack(spacing: 6) {
                        Text(lesson.startLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .leading)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: lesson.colorHex))
                            .frame(width: 3, height: 12)
                        Text(lesson.subject)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let room = lesson.room, !room.isEmpty {
                            Text(room)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if !substitutions.isEmpty {
                    chip("\(substitutions.count) Vertretung\(substitutions.count == 1 ? "" : "en")",
                         systemImage: "arrow.triangle.2.circlepath",
                         tint: .red)
                }
                if !dueTomorrow.isEmpty {
                    chip("\(dueTomorrow.count) Aufgabe\(dueTomorrow.count == 1 ? "" : "n") bis morgen",
                         systemImage: "checklist",
                         tint: .orange)
                }
                if substitutions.isEmpty && dueTomorrow.isEmpty {
                    chip("Alles im Plan", systemImage: "checkmark.circle", tint: .green)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func remainingLessons(_ snapshot: SharedSnapshot, at date: Date) -> [SharedLesson] {
        let cal = SharedSnapshot.calendar
        let minutes = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        return Array(snapshot.lessons(on: date).filter { $0.endMinutes > minutes }.prefix(3))
    }

    private func chip(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: .capsule)
            .lineLimit(1)
    }
}
