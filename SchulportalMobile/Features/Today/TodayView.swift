import SwiftUI

/// The screen you open in the morning: what's next, and what you still owe.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Homework?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let message = model.lastErrorMessage {
                        InlineErrorBanner(message: message) {
                            Task { await model.refresh() }
                        }
                    }
                    nextLessonCard
                    todaysLessonsCard
                    homeworkCard
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

    @ViewBuilder
    private var nextLessonCard: some View {
        if let lesson = model.currentOrNextLesson {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isOngoing(lesson) ? "Gerade" : "Als Nächstes")
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

    @ViewBuilder
    private var todaysLessonsCard: some View {
        let lessons = model.todaysLessons
        if !lessons.isEmpty {
            Card(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Heute · \(GermanDate.weekdayDayMonth.string(from: Date()))")
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

    private func isOngoing(_ lesson: TimetableEntry) -> Bool {
        let now = GermanDate.calendar.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return lesson.start.minutesFromMidnight <= minutes && minutes < lesson.end.minutesFromMidnight
    }
}
