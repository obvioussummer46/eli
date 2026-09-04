import SwiftUI
import WidgetKit

/// Days until the next holidays — and, underneath, the next exam. The one
/// widget that is about hope rather than duty.
struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.countdown, provider: SnapshotProvider()) { entry in
            PremiumGate(entry: entry, title: "Countdown") {
                CountdownView(entry: entry)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Countdown")
        .description("Tage bis zu den Ferien und bis zur nächsten Arbeit.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct CountdownView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else if family == .accessoryCircular {
                Image(systemName: "hourglass")
            } else {
                OpenAppHint()
            }
        }
        .widgetURL(WidgetLink.heute)
    }

    @ViewBuilder
    private func content(_ snapshot: SharedSnapshot) -> some View {
        let holiday = snapshot.nextEvent(after: entry.date, where: { $0.isHoliday })
        let exam = snapshot.nextEvent(after: entry.date, where: { $0.isExam })
        let any = snapshot.nextEvent(after: entry.date, where: { _ in true })
        // Holidays lead; a school without a calendar module, or with no
        // holidays entered, gets the next exam or the next event instead.
        let lead = holiday ?? exam ?? any

        switch family {
        case .accessoryCircular:
            if let lead {
                VStack(spacing: -2) {
                    Text("\(SharedSnapshot.daysUntil(lead, from: entry.date))")
                        .font(.title2.bold().monospacedDigit())
                    Text("Tage").font(.caption2)
                }
            } else {
                Image(systemName: "hourglass")
            }
        case .accessoryInline:
            if let lead {
                Label(inlineLabel(lead), systemImage: lead.isHoliday ? "sun.max" : "hourglass")
            } else {
                Label("Keine Termine", systemImage: "hourglass")
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let lead {
                    Text(inlineLabel(lead)).font(.headline).lineLimit(1)
                    if let exam, exam.id != lead.id {
                        Text(inlineLabel(exam)).font(.caption2).lineLimit(1)
                    }
                } else {
                    Text("Keine Termine").font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                if let lead {
                    Label(lead.isHoliday ? "Ferien" : (lead.isExam ? "Nächste Arbeit" : "Nächster Termin"),
                          systemImage: lead.isHoliday ? "sun.max" : "hourglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(SharedSnapshot.daysUntil(lead, from: entry.date))")
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        Text(SharedSnapshot.daysUntil(lead, from: entry.date) == 1 ? "Tag" : "Tage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(lead.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    if let exam, exam.id != lead.id {
                        Spacer(minLength: 0)
                        Label(inlineLabel(exam), systemImage: "pencil.and.list.clipboard")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Keine Termine")
                        .font(.headline)
                    Text("Der Schulkalender hat nichts Kommendes.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func inlineLabel(_ event: SharedEvent) -> String {
        let days = SharedSnapshot.daysUntil(event, from: entry.date)
        switch days {
        case 0: return "Heute: \(event.title)"
        case 1: return "Morgen: \(event.title)"
        default: return "\(days) Tage bis \(event.title)"
        }
    }
}
