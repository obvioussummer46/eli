import SwiftUI

/// The whole school calendar as fetched, grouped by month — the sheet behind
/// the Heute tab's Termine card. A chip row narrows it to the Arbeiten or
/// to one of the school's own categories.
struct EventsListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var filter: Filter = .all

    enum Filter: Hashable {
        case all
        case exams
        case category(String)

        var label: String {
            switch self {
            case .all: return "Alle"
            case .exams: return "Arbeiten"
            case .category(let name): return name
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                let months = groupedByMonth
                if months.isEmpty {
                    EmptyStateView(icon: "calendar",
                                   title: filter == .all ? "Keine Termine" : "Nichts dabei",
                                   message: filter == .all
                                       ? "Der Schulkalender hat für die nächste Zeit nichts eingetragen."
                                       : "Unter „\(filter.label)“ steht gerade nichts an.")
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(months, id: \.label) { month in
                        Section(month.label) {
                            ForEach(month.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    EventRow(event: event)
                                    let description = event.displayDescription
                                    if !description.isEmpty {
                                        Text(description)
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
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .navigationTitle("Termine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { item in
                    chip(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func chip(_ item: Filter) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            Text(item.label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.tertiarySystemFill), in: .capsule)
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    /// "Alle", "Arbeiten" (only when there are any), then the school's own
    /// categories in order of first appearance.
    private var filters: [Filter] {
        let upcoming = model.upcomingEvents
        var result: [Filter] = [.all]
        if upcoming.contains(where: \.isExam) { result.append(.exams) }
        var seen: Set<String> = []
        for event in upcoming {
            guard let name = event.categoryName, !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(.category(name))
        }
        return result
    }

    private var filtered: [SchoolEvent] {
        let upcoming = model.upcomingEvents
        switch filter {
        case .all: return upcoming
        case .exams: return upcoming.filter(\.isExam)
        case .category(let name): return upcoming.filter { $0.categoryName == name }
        }
    }

    private var groupedByMonth: [(label: String, events: [SchoolEvent])] {
        var order: [String] = []
        var groups: [String: [SchoolEvent]] = [:]
        for event in filtered {
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
