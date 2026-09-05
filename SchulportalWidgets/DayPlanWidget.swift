import SwiftUI
import WidgetKit

/// The whole school day, large: every lesson with its substitution written
/// in, the due homework at the bottom. Rolls over to the next school day
/// once today's last lesson has ended — the same rule as the Heute tab.
struct DayPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.dayPlan, provider: SnapshotProvider()) { entry in
            PremiumGate(entry: entry, title: "Tagesplan") {
                DayPlanView(entry: entry)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tagesplan")
        .description("Der ganze Tag mit Vertretungen und fälligen Aufgaben.")
        .supportedFamilies([.systemLarge])
    }
}

struct DayPlanView: View {
    let entry: SnapshotEntry

    private var isWeekend: Bool {
        entry.snapshot?.isWeekendPause(at: entry.date) ?? false
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if isWeekend {
                    WeekendView(snapshot: snapshot, date: entry.date)
                } else {
                    content(snapshot)
                }
            } else {
                OpenAppHint()
            }
        }
        .widgetURL(isWeekend ? WidgetLink.aufgaben : WidgetLink.plan)
    }

    private func content(_ snapshot: SharedSnapshot) -> some View {
        let cal = SharedSnapshot.calendar
        let now = entry.date
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let todayDone = !snapshot.lessons(on: now).contains { $0.endMinutes > minutes }
        let day = todayDone ? (snapshot.nextSchoolDay(after: now) ?? now) : now
        let isToday = cal.isDate(day, inSameDayAs: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let lessons = snapshot.lessons(on: day)
        let substitutions = snapshot.substitutions(on: day)
        let due = snapshot.homework(dueOn: isToday ? tomorrow : day)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title(day, isToday: isToday, tomorrow: tomorrow))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !substitutions.isEmpty {
                    Label("\(substitutions.count)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            if lessons.isEmpty {
                Text("Keine Stunden — schulfrei 🎉")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(lessons.prefix(9), id: \.self) { lesson in
                    let ongoing = isToday && lesson.startMinutes <= minutes && minutes < lesson.endMinutes
                    let over = isToday && lesson.endMinutes <= minutes
                    let sub = substitution(for: lesson, in: substitutions)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("\(lesson.startLabel)–\(lesson.endLabel)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 74, alignment: .leading)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: lesson.colorHex))
                                .frame(width: 3, height: 12)
                            Text(lesson.subject)
                                .font(.caption.weight(ongoing ? .bold : .medium))
                                .strikethrough(sub?.kind?.lowercased().contains("entfall") == true)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if let room = lesson.room, !room.isEmpty {
                                Text(room)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let sub {
                            Text(sub.summary)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .padding(.leading, 83)
                        }
                    }
                    .opacity(over ? 0.45 : 1)
                }
                Spacer(minLength: 0)
            }

            if !due.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(isToday ? "Bis morgen" : "Fällig"): " + due.map(\.subject).joined(separator: ", "))
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func title(_ day: Date, isToday: Bool, tomorrow: Date) -> String {
        let dated = WidgetFormat.weekdayDayMonth.string(from: day)
        if isToday { return "Heute · \(dated)" }
        return SharedSnapshot.calendar.isDate(day, inSameDayAs: tomorrow) ? "Morgen · \(dated)" : dated
    }

    /// The Vertretungsplan speaks in periods ("3", "3 - 4"), the timetable
    /// in minutes; the subject name is the one reliable bridge. Fallback:
    /// nothing — better an unmatched substitution in the count above than a
    /// wrong one under a lesson.
    private func substitution(for lesson: SharedLesson, in subs: [SharedSubstitution]) -> SharedSubstitution? {
        subs.first { sub in
            guard let subject = sub.subject, !subject.isEmpty else { return false }
            return subject.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                == lesson.subject.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }
    }
}
