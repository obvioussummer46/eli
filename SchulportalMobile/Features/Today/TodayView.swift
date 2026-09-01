import SwiftUI

/// The screen you open in the morning: what's next, and what you still owe.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Homework?
    @State private var isShowingEvents = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let message = model.lastErrorMessage {
                        InlineErrorBanner(message: message) {
                            Task { await model.refresh() }
                        }
                    }
                    if let notice = model.accountNotice {
                        InlineInfoBanner(message: notice)
                    }
                    substitutionsCard
                    nextLessonCard
                    todaysLessonsCard
                    homeworkCard
                    eventsCard
                    footer
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .refreshable { await model.refresh() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }
            }
            .sheet(item: $selection) { item in
                HomeworkDetailView(homework: item).environment(model)
            }
            .sheet(isPresented: $isShowingEvents) {
                EventsListView().environment(model)
            }
        }
    }

    private var greeting: String {
        let hour = GermanDate.calendar.component(.hour, from: Date())
        switch hour {
        case 0..<11: return "Guten Morgen"
        case 11..<18: return "Hallo"
        default: return "Guten Abend"
        }
    }

    // MARK: - Cards

    /// Today's substitutions — or, once today has none (typically from the
    /// afternoon on), the next day's, which is what the evening look at the
    /// app is really for. Absent entirely when there is nothing to say: a
    /// permanent "keine Vertretungen" card would only be noise.
    @ViewBuilder
    private var substitutionsCard: some View {
        let today = model.todaysSubstitutions
        let todayInfos = model.todaysSubstitutionInfos
        if !today.isEmpty || !todayInfos.isEmpty {
            SubstitutionsCard(title: "Vertretungen heute", entries: today, infos: todayInfos)
        } else if let next = model.nextSubstitutionDay {
            SubstitutionsCard(title: "Vertretungen \(GermanDate.relativeLabel(for: next.date))",
                              entries: next.entries,
                              infos: next.infos)
        }
    }

    /// The next few school events — and the door to the full list.
    @ViewBuilder
    private var eventsCard: some View {
        let upcoming = model.upcomingEvents
        if !upcoming.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Termine")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(upcoming.prefix(4)) { event in
                        EventRow(event: event)
                    }
                    if upcoming.count > 4 {
                        Button {
                            isShowingEvents = true
                        } label: {
                            Label("Alle \(upcoming.count) Termine", systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextLessonCard: some View {
        if let lesson = model.heuteNextLesson {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(nextLessonHeader(lesson))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(lesson.subject.color)
                            .frame(width: 5, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lesson.subject.name).font(.title3.bold())
                            HStack(spacing: 8) {
                                Text("\(lesson.start.description)–\(lesson.end.description)")
                                if let room = lesson.room, !room.isEmpty {
                                    Label(room, systemImage: "mappin.and.ellipse")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    /// After the last lesson the interesting day is the next school day —
    /// same rule as the widget, and the label travels with the data.
    @ViewBuilder
    private var todaysLessonsCard: some View {
        let lessons = model.heuteLessons
        if !lessons.isEmpty {
            Card(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(lessonsCardTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    ForEach(lessons) { lesson in
                        HStack(spacing: 10) {
                            Text(lesson.start.description)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            SubjectChip(subject: lesson.subject, compact: true)
                            Text(lesson.room ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        if lesson.id != lessons.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                    Color.clear.frame(height: 12)
                }
            }
        }
    }

    @ViewBuilder
    private var homeworkCard: some View {
        let open = model.openHomework
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("📚 Offene Hausaufgaben")
                        .font(.headline)
                    Spacer()
                    Text("\(open.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(open.isEmpty ? Color.secondary : Color.accentColor)
                }
                if open.isEmpty {
                    Text("Nichts offen. Genieß den Nachmittag.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(open.prefix(5)) { item in
                        Divider()
                        HomeworkRow(homework: item)
                            .onTapGesture { selection = item }
                    }
                    if open.count > 5 {
                        Text("… und \(open.count - 5) weitere im Tab „Aufgaben“")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let last = model.snapshot.lastRefresh {
            Text("Zuletzt aktualisiert: \(last.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var lessonsCardTitle: String {
        let day = model.heuteDay
        let dated = GermanDate.weekdayDayMonth.string(from: day.date)
        if day.isToday { return "Heute · \(dated)" }
        if GermanDate.calendar.isDateInTomorrow(day.date) { return "Morgen · \(dated)" }
        return dated
    }

    private func nextLessonHeader(_ lesson: TimetableEntry) -> String {
        let day = model.heuteDay
        if day.isToday { return isOngoing(lesson) ? "Gerade" : "Als Nächstes" }
        if GermanDate.calendar.isDateInTomorrow(day.date) { return "Morgen als Erstes" }
        return "Am \(GermanDate.weekdayName.string(from: day.date)) als Erstes"
    }

    private func isOngoing(_ lesson: TimetableEntry) -> Bool {
        let now = GermanDate.calendar.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return lesson.start.minutesFromMidnight <= minutes && minutes < lesson.end.minutesFromMidnight
    }
}

private struct SubstitutionsCard: View {
    let title: String
    let entries: [Substitution]
    var infos: [SubstitutionInfo] = []

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.period)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 36, alignment: .leading)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if let subject = entry.subject ?? entry.previousSubject {
                                    Text(subject).font(.subheadline.weight(.semibold))
                                }
                                if let kind = entry.kind, !kind.isEmpty {
                                    Text(kind)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(isCancellation(kind) ? Color.red : Color.accentColor,
                                                    in: .capsule)
                                }
                            }
                            let detail = entry.summary
                            if !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                // The day's Hinweise — school-wide free text, below the rows.
                ForEach(infos, id: \.self) { info in
                    VStack(alignment: .leading, spacing: 2) {
                        if !info.header.isEmpty {
                            Text(info.header)
                                .font(.caption.weight(.semibold))
                        }
                        ForEach(info.values, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func isCancellation(_ kind: String) -> Bool {
        kind.localizedCaseInsensitiveContains("entfall") || kind.localizedCaseInsensitiveContains("entfällt")
    }
}

/// One school event, compact — used by the Heute card and the full list.
struct EventRow: View {
    let event: SchoolEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(event.dateLabel)
                    if let place = event.place, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let category = event.categoryName {
                Text(category)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(event.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.color.opacity(0.14), in: .capsule)
            }
        }
    }
}
