import SwiftUI

/// The whole school calendar as fetched, grouped by month — the sheet behind
/// the Heute tab's Termine card.
struct EventsListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let months = groupedByMonth
                if months.isEmpty {
                    EmptyStateView(icon: "calendar",
                                   title: "Keine Termine",
                                   message: "Der Schulkalender hat für die nächste Zeit nichts eingetragen.")
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(months, id: \.label) { month in
                        Section(month.label) {
                            ForEach(month.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    EventRow(event: event)
                                    if !event.description.isEmpty {
                                        Text(event.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Termine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var groupedByMonth: [(label: String, events: [SchoolEvent])] {
        let upcoming = model.upcomingEvents
        var order: [String] = []
        var groups: [String: [SchoolEvent]] = [:]
        for event in upcoming {
            let label = Self.monthLabel.string(from: event.start)
            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(event)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private static let monthLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = GermanDate.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}
