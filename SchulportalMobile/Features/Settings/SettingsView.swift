import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingSignOut = false
    @State private var isShowingCalendarSheet = false
    @State private var isShowingSchoolPicker = false

    /// The name when the school was picked from the directory, otherwise the
    /// bare number — which is all older installs ever stored.
    private var schoolDescription: String {
        let settings = model.settings
        if !settings.schoolName.isEmpty { return settings.schoolName }
        return settings.schoolID.isEmpty ? "Auswählen" : "Schulnummer \(settings.schoolID)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    Button {
                        isShowingSchoolPicker = true
                    } label: {
                        LabeledContent("Schule") {
                            Text(schoolDescription)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .tint(.primary)
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
                    // "Kein Passwort wird gespeichert" was true until the
                    // Essen tab arrived: the Schulportal is a web-view login
                    // and never hands one over, but menuebestellung.de has
                    // nothing else, and its password does go into the
                    // Keychain. Saying otherwise is the app being wrong about
                    // where someone's password is.
                    Text("Inoffizielle App. Sie liest genau die Seiten, die du auch im Browser siehst, und speichert nichts außerhalb deines Geräts. Fürs Schulportal wird kein Passwort gespeichert — nur die Zugangsdaten fürs Bestellsystem im Tab „Essen“ liegen im Schlüsselbund deines Geräts.")
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
            .sheet(isPresented: $isShowingSchoolPicker) {
                // Changing it here only preselects the *next* sign-in; the
                // session that is running belongs to whichever school it was
                // opened with, so nothing is reloaded.
                SchoolPickerView { school in
                    model.settings.schoolID = school.id
                    model.settings.schoolName = school.name
                }
            }
        }
    }
}
