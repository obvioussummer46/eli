import SwiftUI

struct TimetableView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case day = "Tag"
        case week = "Woche"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .day
    @State private var selectedDay: Weekday = .monday
    @State private var isShowingCalendarSheet = false

    private var timetable: Timetable { model.timetable }

    var body: some View {
        NavigationStack {
            Group {
                if timetable.isEmpty {
                    ScrollView {
                        EmptyStateView(icon: "calendar.badge.exclamationmark",
                                       title: "Kein Stundenplan geladen",
                                       message: "Tippe auf Aktualisieren. Falls deine Schule den Stundenplan nicht im Portal veröffentlicht, bleibt diese Seite leer.")
                    }
                    .refreshable { await model.refresh() }
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stundenplan")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        ActivitiesView()
                            .environment(model)
                    } label: {
                        Image(systemName: "figure.run")
                    }
                    .accessibilityLabel("AGs & Termine")
                    Button {
                        isShowingCalendarSheet = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("In iOS-Kalender übertragen")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Ansicht", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
            .sheet(isPresented: $isShowingCalendarSheet) {
                CalendarSyncView()
                    .environment(model)
            }
        }
        .onAppear {
            if let today = model.today, (1...5).contains(today.rawValue) {
                selectedDay = today
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            dayList
        case .week:
            TimetableWeekGrid(timetable: timetable)
        }
    }

    private var dayList: some View {
        VStack(spacing: 0) {
            Picker("Tag", selection: $selectedDay) {
                ForEach(days) { day in
                    Text(day.shortName).tag(day)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            List {
                let lessons = timetable.entries(on: selectedDay)
                if lessons.isEmpty {
                    EmptyStateView(icon: "sun.max", title: "Frei", message: "An diesem Tag steht nichts im Plan.")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(lessons) { entry in
                        LessonRow(entry: entry, isNow: isNow(entry))
                    }
                }
                if let validFrom = timetable.validFrom {
                    Section {
                        Text(validFrom)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await model.refresh() }
        }
    }

    private var days: [Weekday] {
        let used = timetable.weekdaysInUse
        return used.isEmpty ? [.monday, .tuesday, .wednesday, .thursday, .friday] : used
    }

    private func isNow(_ entry: TimetableEntry) -> Bool {
        guard model.today == entry.weekday, selectedDay == entry.weekday else { return false }
        let now = GermanDate.calendar.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return entry.start.minutesFromMidnight <= minutes && minutes < entry.end.minutesFromMidnight
    }
}

struct LessonRow: View {
    let entry: TimetableEntry
    var isNow = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.start.description)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(entry.end.description)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.subject.color)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.subject.name)
                        .font(.headline)
                    if entry.isActivity {
                        ActivityTag()
                    }
                    if isNow {
                        Text("jetzt")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor, in: .capsule)
                    }
                }
                HStack(spacing: 8) {
                    Text(entry.slotLabel)
                    if let room = entry.room, !room.isEmpty {
                        Label(room, systemImage: "mappin.and.ellipse")
                    }
                    if let teacher = entry.teacher, !teacher.isEmpty {
                        Text(teacher)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .listRowBackground(isNow ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
    }
}

/// The small "AG" mark on an entry the user added — so nobody wonders why
/// the portal's plan has a lesson the portal never mentioned.
struct ActivityTag: View {
    var body: some View {
        Text(SchoolActivity.subjectCode)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
    }
}
