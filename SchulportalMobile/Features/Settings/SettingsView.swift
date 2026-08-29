import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingSignOut = false
    @State private var isShowingCalendarSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    LabeledContent("Schulnummer", value: model.settings.schoolID.isEmpty ? "—" : model.settings.schoolID)
                    if let last = model.snapshot.lastRefresh {
                        LabeledContent("Zuletzt geladen", value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Abmelden", role: .destructive) { isConfirmingSignOut = true }
                }

                Section("Daten") {
                    Toggle("Beim Start aktualisieren", isOn: Binding(
                        get: { model.settings.refreshesOnLaunch },
                        set: { model.settings.refreshesOnLaunch = $0 }
                    ))
                    Toggle("Erledigte Hausaufgaben ausblenden", isOn: Binding(
                        get: { model.settings.hidesDoneHomework },
                        set: { model.settings.hidesDoneHomework = $0 }
                    ))
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Jetzt aktualisieren", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }

                Section {
                    Button {
                        isShowingCalendarSheet = true
                    } label: {
                        Label("Stundenplan in den iOS-Kalender", systemImage: "calendar.badge.plus")
                    }
                } header: {
                    Text("Kalender")
                } footer: {
                    Text(model.settings.calendarIdentifier == nil
                         ? "Noch nicht übertragen."
                         : "Ein eigener Kalender ist angelegt. Beim erneuten Übertragen wird er aktualisiert.")
                }

                Section("Statistik") {
                    LabeledContent("Kurse", value: "\(model.snapshot.courses.count)")
                    LabeledContent("Einträge", value: "\(model.snapshot.entries.count)")
                    LabeledContent("Offene Hausaufgaben", value: "\(model.openHomework.count)")
                    LabeledContent("Stunden im Plan", value: "\(model.snapshot.timetable.entries.count)")
                }

                // The portal itself lives in the Portal tab — including its
                // own „In Safari öffnen“. A second way in from here only made
                // it ambiguous which of the two was the real one.
                Section("Über") {
                    Text("Inoffizielle App. Sie liest genau die Seiten, die du auch im Browser siehst, und speichert nichts außerhalb deines Geräts. Kein Passwort wird gespeichert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .confirmationDialog("Wirklich abmelden?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) {
                    Task { await model.signOut() }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die lokal gespeicherten Hausaufgaben-Haken werden dabei gelöscht.")
            }
            .sheet(isPresented: $isShowingCalendarSheet) {
                CalendarSyncView().environment(model)
            }
        }
    }
}
