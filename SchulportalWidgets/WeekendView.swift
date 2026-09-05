import SwiftUI
import WidgetKit

/// What the school widgets show on a Saturday: not Monday's lessons, which
/// nobody wants to think about yet, but the homework that would free up
/// Sunday. Same snapshot, different question.
struct WeekendView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: SharedSnapshot
    let date: Date

    private var open: [SharedHomework] { snapshot.openHomework() }

    private var dueOnNextSchoolDay: [String] {
        guard let next = snapshot.nextSchoolDay(after: date) else { return [] }
        return snapshot.deadlineSubjects(on: next)
    }

    private var countLine: String {
        open.isEmpty ? "Alles erledigt" : "\(open.count) Aufgabe\(open.count == 1 ? "" : "n") offen"
    }

    private var nudge: String {
        open.isEmpty ? "Der Sonntag ist frei." : "Heute erledigen — dann ist der Sonntag frei."
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Wochenende").font(.headline)
                Text(countLine).font(.caption2)
                if !open.isEmpty {
                    Text("Heute erledigen, Sonntag frei").font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                Text("Wochenende 🎉")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(countLine)
                    .font(.title3.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(nudge)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Wochenende 🎉 · \(WidgetFormat.weekdayDayMonth.string(from: date))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(open.isEmpty ? "Alles erledigt — genieß die zwei Tage." : "\(countLine) — heute erledigen, Sonntag frei.")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(open.prefix(family == .systemLarge ? 6 : 2)) { item in
                    HStack(spacing: 6) {
                        Text(item.subject)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color(hex: item.colorHex), in: .capsule)
                            .lineLimit(1)
                        Text(item.text)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    let due = dueOnNextSchoolDay
                    if due.isEmpty {
                        WeekendChip(text: "Nichts bis Montag fällig", systemImage: "checkmark.circle", tint: .green)
                    } else {
                        WeekendChip(text: "\(due.count) bis Montag", systemImage: "checklist", tint: .orange)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct WeekendChip: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: .capsule)
            .lineLimit(1)
    }
}
