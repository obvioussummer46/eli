import AppIntents
import SwiftUI
import WidgetKit

/// Open homework on the home screen, with a working tick: the tap records
/// the flag in the App Group and the app pushes it to the portal on its
/// next foreground — the same "local wins, sync later" rule as in the app.
struct HomeworkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.homework, provider: SnapshotProvider()) { entry in
            PremiumGate(entry: entry, title: "Aufgaben") {
                HomeworkWidgetView(entry: entry)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aufgaben")
        .description("Offene Hausaufgaben — direkt hier abhaken.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct HomeworkWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else if family == .accessoryCircular {
                Image(systemName: "checklist")
            } else {
                OpenAppHint()
            }
        }
        .widgetURL(WidgetLink.aufgaben)
    }

    @ViewBuilder
    private func content(_ snapshot: SharedSnapshot) -> some View {
        let open = snapshot.openHomework()
        let tomorrow = SharedSnapshot.calendar.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
        let dueSoon = open.filter { item in
            guard let deadline = item.deadline else { return false }
            return SharedSnapshot.calendar.startOfDay(for: deadline) <= SharedSnapshot.calendar.startOfDay(for: tomorrow)
        }
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "checklist").font(.caption2)
                Text("\(open.count)").font(.title3.bold().monospacedDigit())
            }
        case .accessoryInline:
            if open.isEmpty {
                Label("Keine offenen Aufgaben", systemImage: "checkmark.circle")
            } else {
                Label(dueSoon.isEmpty
                      ? "\(open.count) Aufgabe\(open.count == 1 ? "" : "n") offen"
                      : "\(dueSoon.count) bis morgen · \(open.count) offen",
                      systemImage: "checklist")
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(open.isEmpty ? "Alles erledigt" : "\(open.count) offen")
                    .font(.headline)
                ForEach(open.prefix(2)) { item in
                    Text("\(item.subject): \(item.text)")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            list(open, limit: family == .systemLarge ? 8 : 3)
        }
    }

    private func list(_ open: [SharedHomework], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Aufgaben")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !open.isEmpty {
                    Text("\(open.count) offen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if open.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Alles erledigt 🎉")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(open.prefix(limit)) { item in
                    row(item)
                }
                if open.count > limit {
                    Text("+ \(open.count - limit) weitere")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ item: SharedHomework) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // The tick. `Button(intent:)` runs in the extension without
            // opening the app — that is the whole point of the widget.
            Button(intent: MarkHomeworkDoneIntent(homeworkID: item.id)) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.subject)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color(hex: item.colorHex), in: .capsule)
                        .lineLimit(1)
                    if let deadline = item.deadline {
                        Text(deadlineLabel(deadline))
                            .font(.caption2)
                            .foregroundStyle(isOverdue(deadline) ? .red : .secondary)
                    }
                }
                Text(item.text)
                    .font(.caption)
                    .lineLimit(family == .systemLarge ? 2 : 1)
            }
        }
    }

    private func deadlineLabel(_ deadline: Date) -> String {
        let cal = SharedSnapshot.calendar
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: entry.date), to: cal.startOfDay(for: deadline)).day ?? 0
        switch days {
        case ..<0: return "überfällig"
        case 0: return "heute"
        case 1: return "morgen"
        default: return WidgetFormat.weekdayShort.string(from: deadline)
        }
    }

    private func isOverdue(_ deadline: Date) -> Bool {
        deadline < SharedSnapshot.calendar.startOfDay(for: entry.date)
    }
}
