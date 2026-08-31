import SwiftUI
import WidgetKit

/// The question a pupil asks between every lesson: what now, and where?
struct NextLessonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextLesson", provider: SnapshotProvider()) { entry in
            NextLessonView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nächste Stunde")
        .description("Was jetzt dran ist — mit Zeit und Raum.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct NextLessonView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            OpenAppHint()
        }
    }

    @ViewBuilder
    private func content(_ snapshot: SharedSnapshot) -> some View {
        let cal = SharedSnapshot.calendar
        if let lesson = snapshot.currentOrNextLesson(at: entry.date) {
            lessonView(lesson,
                       header: isOngoing(lesson) ? "Jetzt" : "Als Nächstes",
                       accent: Color(hex: lesson.colorHex))
        } else if let tomorrow = cal.date(byAdding: .day, value: 1, to: entry.date),
                  let first = snapshot.lessons(on: tomorrow).first {
            lessonView(first,
                       header: "Morgen",
                       accent: Color(hex: first.colorHex))
        } else {
            VStack(spacing: 4) {
                Text("🎉").font(.title)
                Text("Schulfrei")
                    .font(family == .accessoryRectangular ? .caption : .headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func lessonView(_ lesson: SharedLesson, header: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: family == .accessoryRectangular ? 1 : 4) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(family == .accessoryRectangular ? AnyShapeStyle(.secondary) : AnyShapeStyle(accent))
            Text(lesson.subject)
                .font(family == .accessoryRectangular ? .headline : .title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(lesson.startLabel)–\(lesson.endLabel)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if let room = lesson.room, !room.isEmpty {
                Label(room, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func isOngoing(_ lesson: SharedLesson) -> Bool {
        let cal = SharedSnapshot.calendar
        let minutes = cal.component(.hour, from: entry.date) * 60 + cal.component(.minute, from: entry.date)
        return lesson.startMinutes <= minutes && minutes < lesson.endMinutes
    }
}
