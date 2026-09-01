import SwiftUI
import WidgetKit

/// The lunch card, on the lock screen: what is left, and what is ordered.
struct MensaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Mensa", provider: SnapshotProvider()) { entry in
            MensaView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mensa")
        .description("Guthaben auf der Karte und das bestellte Essen.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct MensaView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.balanceText != nil {
                content(snapshot)
            } else if family == .accessoryCircular {
                Image(systemName: "fork.knife")
            } else {
                OpenAppHint()
            }
        }
        .widgetURL(WidgetLink.essen)
    }

    @ViewBuilder
    private func content(_ snapshot: SharedSnapshot) -> some View {
        let balance = snapshot.balanceText ?? "—"
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "fork.knife")
                    .font(.caption2)
                Text(balance.replacingOccurrences(of: " €", with: ""))
                    .font(.caption.bold().monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("Mensa", systemImage: "fork.knife")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(balance)
                    .font(.title2.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                if let dish = todaysOrRow(snapshot) {
                    Text(dish.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(dish.title)
                        .font(.caption)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Today's ordered dish while lunch is still ahead-ish, tomorrow's
    /// afterwards — matching when the question actually comes up.
    private func todaysOrRow(_ snapshot: SharedSnapshot) -> (label: String, title: String)? {
        let cal = SharedSnapshot.calendar
        let hour = cal.component(.hour, from: entry.date)
        if hour < 14, let dish = snapshot.orderedDish(on: entry.date) {
            return ("Heute bestellt", dish)
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: entry.date),
           let dish = snapshot.orderedDish(on: tomorrow) {
            return ("Morgen bestellt", dish)
        }
        if hour >= 14, let dish = snapshot.orderedDish(on: entry.date) {
            return ("Heute bestellt", dish)
        }
        return nil
    }
}
