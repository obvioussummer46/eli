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
                // The pages the app does not parse natively — Nachrichten,
                // Vertretungsplan, Kalender — live behind this one link. It
                // used to be a tab of its own, but a sixth tab pushes iOS
                // into its automatic "Mehr" overflow and buries both.
                Section {
                    NavigationLink {
                        PortalBrowserView()
                    } label: {
                        Label("Schulportal öffnen", systemImage: "safari")
                    }
                } footer: {
                    Text("Nachrichten, Vertretungsplan, Kalender & Co. — das ganze Portal im mobilen Design.")
                }

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
                    if let username = model.portalUsername {
                        LabeledContent("Angemeldet als", value: username)
                    }
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
                    Toggle("Abends an fällige Aufgaben erinnern", isOn: Binding(
                        get: { model.settings.notifiesHomework },
                        set: { enabled in
                            model.settings.notifiesHomework = enabled
                            if enabled { Task { _ = await NotificationScheduler.requestAuthorization() } }
                        }
                    ))
                    Toggle("Warnen, wenn das Mensa-Guthaben knapp wird", isOn: Binding(
                        get: { model.settings.notifiesLowBalance },
                        set: { enabled in
                            model.settings.notifiesLowBalance = enabled
                            if enabled { Task { _ = await NotificationScheduler.requestAuthorization() } }
                        }
                    ))
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    Text("Die Erinnerung kommt um 17 Uhr am Vortag — für Aufgaben mit Abgabedatum und für alles, dessen Fach am nächsten Tag auf dem Plan steht. Alles bleibt auf dem Gerät.")
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

                Section("Über") {
                    // Precise about the passwords: both accounts *can* live in
                    // the Keychain, but the Schulportal one only when the
                    // native login was used — the browser route never hands
                    // one over. The app being vague about where someone's
                    // password is would be worse than the longer sentence.
                    Text("Inoffizielle App. Sie liest genau die Seiten, die du auch im Browser siehst, und speichert nichts außerhalb deines Geräts. Zugangsdaten, die du in der App eingibst — fürs Schulportal und fürs Bestellsystem im Tab „Essen“ — liegen im Schlüsselbund deines Geräts und werden nirgendwohin sonst geschickt. Wer sich über die Portalseite anmeldet, dessen Schulportal-Passwort sieht die App nie.")
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
                Text("Die lokal gespeicherten Hausaufgaben-Haken und die Schulportal-Zugangsdaten im Schlüsselbund werden dabei gelöscht.")
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
