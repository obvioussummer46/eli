import SwiftUI

/// The user's own AGs and fixed appointments, by weekday. Add, edit, swipe to
/// delete — everything else (Heute, Plan, widgets, calendar) picks them up
/// through the merged timetable.
struct ActivitiesView: View {
    @Environment(AppModel.self) private var model
    @State private var isAdding = false
    @State private var editing: SchoolActivity?

    private var activities: [SchoolActivity] { model.settings.activities }

    private var weekdaysInUse: [Weekday] {
        let used = Set(activities.map(\.weekday))
        return Weekday.allCases.filter { used.contains($0) }
    }

    var body: some View {
        Form {
            if activities.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine AGs eingetragen.")
                            .font(.headline)
                        Text("Nachmittags-AG, Förderkurs, Hort, Instrumentalunterricht — was jede Woche zur gleichen Zeit stattfindet und nicht im Portal steht. Einmal eintragen, dann erscheint es im Stundenplan, auf Heute, im Widget und im Kalender-Export.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            ForEach(weekdaysInUse) { day in
                Section(day.germanName) {
                    ForEach(activities.filter { $0.weekday == day }.sorted { $0.start < $1.start }) { activity in
                        Button {
                            editing = activity
                        } label: {
                            ActivityRow(activity: activity)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                remove(activity)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    isAdding = true
                } label: {
                    Label("AG hinzufügen", systemImage: "plus")
                }
            } footer: {
                if let school = model.settings.registryLinks.first(where: { $0.title.localizedCaseInsensitiveContains("AG") }) {
                    Text("Das AG-Angebot deiner Schule steht unter Mehr › Meine Schule › „\(school.title)“.")
                } else if !activities.isEmpty {
                    Text("Nach links wischen zum Löschen. Antippen zum Bearbeiten.")
                }
            }
        }
        .navigationTitle("AGs & Termine")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("AG hinzufügen")
            }
        }
        .sheet(isPresented: $isAdding) {
            ActivityEditorView(activity: nil) { save($0) }
                .environment(model)
        }
        .sheet(item: $editing) { activity in
            ActivityEditorView(activity: activity) { save($0) }
                .environment(model)
        }
    }

    private func save(_ activity: SchoolActivity) {
        var list = model.settings.activities
        if let index = list.firstIndex(where: { $0.id == activity.id }) {
            list[index] = activity
        } else {
            list.append(activity)
        }
        model.settings.activities = list
        model.activitiesDidChange()
    }

    private func remove(_ activity: SchoolActivity) {
        model.settings.activities.removeAll { $0.id == activity.id }
        model.activitiesDidChange()
    }
}

private struct ActivityRow: View {
    let activity: SchoolActivity

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: activity.colorHex))
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(activity.start.description)–\(activity.end.description)")
                        .monospacedDigit()
                    if let room = activity.room, !room.isEmpty {
                        Label(room, systemImage: "mappin.and.ellipse")
                    }
                    if let leader = activity.leader, !leader.isEmpty {
                        Text(leader)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// One form for adding and editing. When the portal's plan carries a period
/// table, a period can be picked instead of typing times — "8. Stunde" is
/// how the school announces AGs, after all.
struct ActivityEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let original: SchoolActivity?
    let onSave: (SchoolActivity) -> Void

    @State private var title: String
    @State private var weekday: Weekday
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var firstPeriod: Int
    @State private var lastPeriod: Int
    @State private var room: String
    @State private var leader: String
    @State private var note: String

    /// `0` in the period pickers means "Uhrzeit eingeben".
    private static let byTime = 0

    init(activity: SchoolActivity?, onSave: @escaping (SchoolActivity) -> Void) {
        original = activity
        self.onSave = onSave
        let cal = GermanDate.calendar
        let start = activity?.start ?? TimeOfDay(hour: 14, minute: 0)
        let end = activity?.end ?? TimeOfDay(hour: 15, minute: 30)
        _title = State(initialValue: activity?.title ?? "")
        _weekday = State(initialValue: activity?.weekday ?? .monday)
        _startDate = State(initialValue: cal.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: Date()) ?? Date())
        _endDate = State(initialValue: cal.date(bySettingHour: end.hour, minute: end.minute, second: 0, of: Date()) ?? Date())
        _firstPeriod = State(initialValue: Self.byTime)
        _lastPeriod = State(initialValue: Self.byTime)
        _room = State(initialValue: activity?.room ?? "")
        _leader = State(initialValue: activity?.leader ?? "")
        _note = State(initialValue: activity?.note ?? "")
    }

    private var periods: [Period] { model.timetable.periods.sorted { $0.index < $1.index } }

    private var usesPeriods: Bool { firstPeriod != Self.byTime }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Schach-AG", text: $title)
                    Picker("Wochentag", selection: $weekday) {
                        ForEach(Weekday.allCases) { day in
                            Text(day.germanName).tag(day)
                        }
                    }
                }

                Section {
                    if !periods.isEmpty {
                        Picker("Schulstunde", selection: $firstPeriod) {
                            Text("Uhrzeit eingeben").tag(Self.byTime)
                            ForEach(periods) { period in
                                Text("\(period.index). Stunde · \(period.start.description)").tag(period.index)
                            }
                        }
                        .onChange(of: firstPeriod) { _, newValue in
                            if newValue != Self.byTime, lastPeriod < newValue { lastPeriod = newValue }
                        }
                        if usesPeriods {
                            Picker("Bis Stunde", selection: $lastPeriod) {
                                ForEach(periods.filter { $0.index >= firstPeriod }) { period in
                                    Text("\(period.index). Stunde · bis \(period.end.description)").tag(period.index)
                                }
                            }
                        }
                    }
                    if !usesPeriods {
                        DatePicker("Beginn", selection: $startDate, displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: $endDate, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Zeit")
                } footer: {
                    if !isTimeValid {
                        Text("Das Ende muss nach dem Beginn liegen.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Details") {
                    TextField("Raum", text: $room)
                    TextField("Leitung", text: $leader)
                    TextField("Notiz", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(original == nil ? "AG hinzufügen" : "AG bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(makeActivity())
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var resolvedTimes: (start: TimeOfDay, end: TimeOfDay) {
        if usesPeriods,
           let first = periods.first(where: { $0.index == firstPeriod }),
           let last = periods.first(where: { $0.index == max(firstPeriod, lastPeriod) }) {
            return (first.start, last.end)
        }
        let cal = GermanDate.calendar
        let start = cal.dateComponents([.hour, .minute], from: startDate)
        let end = cal.dateComponents([.hour, .minute], from: endDate)
        return (TimeOfDay(hour: start.hour ?? 0, minute: start.minute ?? 0),
                TimeOfDay(hour: end.hour ?? 0, minute: end.minute ?? 0))
    }

    private var isTimeValid: Bool {
        let times = resolvedTimes
        return times.start < times.end
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isTimeValid
    }

    private func makeActivity() -> SchoolActivity {
        let times = resolvedTimes
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        func clean(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        // Keep the colour across edits unless the title changed — a renamed
        // AG is a different thing, a moved one is not.
        let colour = (original?.title == trimmedTitle) ? original?.colorHex : nil
        return SchoolActivity(id: original?.id ?? UUID().uuidString,
                        title: trimmedTitle,
                        weekday: weekday,
                        start: times.start,
                        end: times.end,
                        room: clean(room),
                        leader: clean(leader),
                        note: clean(note),
                        colorHex: colour)
    }
}
