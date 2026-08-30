import EventKit
import SwiftUI

/// Options + trigger for writing the plan into the iOS calendar.
struct CalendarSyncView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var sync = CalendarSync()
    @State private var isWorking = false
    @State private var summary: CalendarSync.Summary?
    @State private var errorMessage: String?
    @State private var isConfirmingRemoval = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: Binding(
                        get: { model.settings.calendarWeeksAhead },
                        set: { model.settings.calendarWeeksAhead = $0 }
                    ), in: 1...26) {
                        LabeledContent("Zeitraum", value: "\(model.settings.calendarWeeksAhead) Wochen")
                    }
                    Toggle("Hausaufgaben als ganztägige Termine", isOn: Binding(
                        get: { model.settings.syncsHomeworkToCalendar },
                        set: { model.settings.syncsHomeworkToCalendar = $0 }
                    ))
                } header: {
                    Text("Was übertragen wird")
                } footer: {
                    Text("Die App legt einen eigenen Kalender „\(CalendarSync.calendarTitle)“ an und schreibt nur dort hinein. Bei jeder Übertragung wird dieser Zeitraum neu geschrieben – Planänderungen kommen so sauber an.")
                }

                Section {
                    Button {
                        Task { await runSync() }
                    } label: {
                        HStack {
                            Label("Jetzt übertragen", systemImage: "calendar.badge.plus")
                            Spacer()
                            if isWorking { ProgressView() }
                        }
                    }
                    .disabled(isWorking || model.snapshot.timetable.isEmpty)
                }

                if let summary {
                    Section("Fertig") {
                        LabeledContent("Stunden", value: "\(summary.lessonEvents)")
                        if summary.homeworkEvents > 0 {
                            LabeledContent("Hausaufgaben", value: "\(summary.homeworkEvents)")
                        }
                        LabeledContent("Kalender", value: summary.calendarTitle)
                        LabeledContent("Bis", value: GermanDate.dayMonthYear.string(from: summary.through))
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if model.settings.calendarIdentifier != nil {
                    Section {
                        Button("Kalender wieder entfernen", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                    } footer: {
                        Text("Löscht den von der App angelegten Kalender samt aller übertragenen Termine. Deine eigenen Kalender bleiben unberührt.")
                    }
                }
            }
            .navigationTitle("In den Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .confirmationDialog("Kalender wirklich entfernen?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    Task { await removeCalendar() }
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private func runSync() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            summary = try await sync.sync(timetable: model.snapshot.timetable,
                                          homework: model.openHomework,
                                          settings: model.settings)
        } catch {
            summary = nil
            errorMessage = [error.localizedDescription, (error as? LocalizedError)?.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: " ")
        }
    }

    private func removeCalendar() async {
        do {
            try await sync.removeManagedCalendar(settings: model.settings)
            summary = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
