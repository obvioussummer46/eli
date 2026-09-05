import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Store.self) private var store
    @State private var isConfirmingSignOut = false
    @State private var isShowingPaywall = false
    @State private var isShowingCalendarSheet = false
    @State private var isShowingSchoolPicker = false
    @State private var presentedLink: SchoolLink?
    @State private var isAddingLink = false
    @State private var newLinkTitle = ""
    @State private var newLinkURL = ""

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

                // Links from the registry plus the user's own — the v1 answer
                // to "school news": the school's website, one tap away,
                // rendered by the school itself and therefore never broken.
                Section {
                    ForEach(model.settings.registryLinks) { link in
                        linkRow(link)
                    }
                    ForEach(model.settings.customLinks) { link in
                        linkRow(link)
                    }
                    .onDelete { offsets in
                        model.settings.customLinks.remove(atOffsets: offsets)
                    }
                    Button {
                        newLinkTitle = ""
                        newLinkURL = ""
                        isAddingLink = true
                    } label: {
                        Label("Link hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Meine Schule")
                } footer: {
                    if model.settings.customLinks.isEmpty {
                        Text("Eigene Links (Hort, Schulwohnung …) lassen sich hinzufügen und nach links wischen zum Löschen.")
                    }
                }

                // What the portal's plan lacks: the afternoon. Entered by
                // hand for every school alike — no school publishes its AGs
                // in a form a program could read.
                Section {
                    NavigationLink {
                        ActivitiesView()
                    } label: {
                        LabeledContent {
                            if !model.settings.activities.isEmpty {
                                Text("\(model.settings.activities.count)")
                            }
                        } label: {
                            Label("AGs & Termine", systemImage: "figure.run")
                        }
                    }
                } footer: {
                    Text("Nachmittags-AG, Förderkurs, Hort — einmal eintragen, dann steht es im Stundenplan, auf Heute, im Widget und im Kalender-Export.")
                }

                // Only while the portal reports any attendance data for this
                // account — no data, no row: hidden, not broken.
                if model.snapshot.attendance?.isEmpty == false {
                    Section {
                        NavigationLink {
                            AttendanceView()
                        } label: {
                            Label("Fehlzeiten", systemImage: "person.crop.circle.badge.clock")
                        }
                    } footer: {
                        Text("Fehlend, entschuldigt, unentschuldigt — je Kurs, wie im Portal erfasst.")
                    }
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
                    Toggle("Essen-Tab anzeigen", isOn: Binding(
                        get: { model.settings.showsMensaTab },
                        set: { shown in
                            model.settings.showsMensaTab = shown
                            if !shown {
                                // The widgets and the digest degrade with the
                                // tab: no balance, no dish — instead of stale
                                // numbers nobody refreshes any more.
                                SharedSnapshotStore.update { snapshot in
                                    snapshot.balanceText = nil
                                    snapshot.orderedDishes = [:]
                                    snapshot.openOrderDays = nil
                                }
                                NotificationScheduler.cancelMensaOrderWarning()
                            }
                        }
                    ))
                    if model.settings.showsMensaTab {
                        LabeledContent("Kennung") {
                            TextField(model.settings.registryConfig?.mensaTenant ?? "z. B. asb-heserv",
                                      text: Binding(
                                        get: { model.settings.mensaTenantOverride },
                                        set: { model.settings.mensaTenantOverride = $0 }
                                      ))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        }
                    }
                } header: {
                    Text("Essen")
                } footer: {
                    Text("Die Kennung ist der Namensteil in der Adresse deiner Schule auf menuebestellung.de (…/kennung/). Leer lassen, wenn die Schule schon eingetragen ist.")
                }

                Section {
                    Toggle("Abend-Überblick für morgen", isOn: Binding(
                        get: { model.settings.notifiesDigest },
                        set: { enabled in
                            model.settings.notifiesDigest = enabled
                            if enabled {
                                Task {
                                    _ = await NotificationScheduler.requestAuthorization()
                                    NotificationScheduler.rescheduleDigest()
                                }
                            } else {
                                NotificationScheduler.cancelDigest()
                            }
                        }
                    ))
                    Toggle("Abends an fällige Aufgaben erinnern", isOn: Binding(
                        get: { model.settings.notifiesHomework },
                        set: { enabled in
                            model.settings.notifiesHomework = enabled
                            if enabled { Task { _ = await NotificationScheduler.requestAuthorization() } }
                        }
                    ))
                    if store.entitlements.isPro {
                        if model.settings.notifiesDigest {
                            timeRow("Überblick um", minutes: Binding(
                                get: { model.settings.digestMinutes },
                                set: { minutes in
                                    model.settings.digestMinutes = minutes
                                    NotificationScheduler.rescheduleDigest()
                                }
                            ))
                        }
                        if model.settings.notifiesHomework {
                            timeRow("Aufgaben-Erinnerung um", minutes: Binding(
                                get: { model.settings.homeworkReminderMinutes },
                                set: { minutes in
                                    model.settings.homeworkReminderMinutes = minutes
                                    // The reminders are rebuilt on the next
                                    // refresh from the live homework list.
                                    Task { await model.refresh() }
                                }
                            ))
                        }
                    } else if model.settings.notifiesDigest || model.settings.notifiesHomework {
                        LockedRow(title: "Uhrzeiten anpassen", systemImage: "clock") {
                            isShowingPaywall = true
                        }
                    }
                    if model.settings.showsMensaTab {
                        Toggle("Warnen, wenn das Mensa-Guthaben knapp wird", isOn: Binding(
                            get: { model.settings.notifiesLowBalance },
                            set: { enabled in
                                model.settings.notifiesLowBalance = enabled
                                if enabled { Task { _ = await NotificationScheduler.requestAuthorization() } }
                            }
                        ))
                        Toggle("Sonntags erinnern, wenn nichts bestellt ist", isOn: Binding(
                            get: { model.settings.notifiesMensaOrders },
                            set: { enabled in
                                model.settings.notifiesMensaOrders = enabled
                                if enabled {
                                    Task {
                                        _ = await NotificationScheduler.requestAuthorization()
                                        NotificationScheduler.rescheduleMensaOrderWarning()
                                    }
                                } else {
                                    NotificationScheduler.cancelMensaOrderWarning()
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    let digest = Settings.timeLabel(minutes: Settings.effectiveDigestMinutes)
                    let reminder = Settings.timeLabel(minutes: Settings.effectiveHomeworkReminderMinutes)
                    Text(model.settings.showsMensaTab
                         ? "Der Überblick kommt um \(digest) Uhr: Stunden, fällige Aufgaben, Vertretungen und das bestellte Essen für morgen. Die Aufgaben-Erinnerung kommt um \(reminder) Uhr am Vortag, die Bestell-Erinnerung sonntags um 17 Uhr für die kommende Woche. Alles bleibt auf dem Gerät."
                         : "Der Überblick kommt um \(digest) Uhr: Stunden, fällige Aufgaben und Vertretungen für morgen. Die Aufgaben-Erinnerung kommt um \(reminder) Uhr am Vortag. Alles bleibt auf dem Gerät.")
                }

                Section {
                    Toggle("Aktuelle Stunde als Live-Aktivität", isOn: Binding(
                        get: { model.settings.showsLiveActivity },
                        set: { enabled in
                            model.settings.showsLiveActivity = enabled
                            if enabled {
                                LessonActivityController.sync(model: model, canStart: true)
                            } else {
                                LessonActivityController.endAll()
                            }
                        }
                    ))
                } header: {
                    Text("Live-Aktivität")
                } footer: {
                    Text("Zeigt die laufende Stunde mit Countdown auf dem Sperrbildschirm und in der Dynamic Island. Aktualisiert sich, wenn die App läuft. Lässt sich hier und in den iOS-Einstellungen jederzeit abschalten.")
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

                // Pro and the tip jar, side by side: the extras and the
                // thank-you. Neither ever pops up on its own.
                Section {
                    if store.entitlements.isPro {
                        NavigationLink {
                            PaywallView()
                        } label: {
                            LabeledContent {
                                Text("Aktiv").foregroundStyle(.green)
                            } label: {
                                Label(Brand.pro, systemImage: "sparkles")
                            }
                        }
                    } else {
                        Button {
                            isShowingPaywall = true
                        } label: {
                            HStack {
                                Label("\(Brand.pro) freischalten", systemImage: "sparkles")
                                Spacer()
                                ProBadge()
                            }
                        }
                        .tint(.primary)
                    }
                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("App unterstützen", systemImage: store.entitlements.hasTipped ? "heart.fill" : "heart")
                    }
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink {
                            AppIconPickerView()
                        } label: {
                            Label("App-Symbol", systemImage: "app.badge")
                        }
                    }
                } footer: {
                    Text(store.entitlements.isPro
                         ? "Danke! Widgets, Symbole und Extras sind freigeschaltet."
                         : "Mehr Widgets, alle Symbole, eigene Erinnerungszeiten. Die App selbst bleibt kostenlos.")
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
            .paywall(isPresented: $isShowingPaywall)
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
            .sheet(item: $presentedLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
            .alert("Link hinzufügen", isPresented: $isAddingLink) {
                TextField("Titel", text: $newLinkTitle)
                TextField("Adresse (z. B. schule.de/hort)", text: $newLinkURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("Hinzufügen") { addCustomLink() }
                Button("Abbrechen", role: .cancel) {}
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

    /// A time-of-day picker bound to minutes-from-midnight — the unit the
    /// scheduler and the settings speak.
    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        let cal = GermanDate.calendar
        let date = Binding<Date>(
            get: {
                cal.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                minutes.wrappedValue = cal.component(.hour, from: newValue) * 60 + cal.component(.minute, from: newValue)
            }
        )
        return DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
    }

    private func linkRow(_ link: SchoolLink) -> some View {
        Button {
            presentedLink = link
        } label: {
            Label(link.title, systemImage: "link")
        }
        .tint(.primary)
    }

    private func addCustomLink() {
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var address = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !address.isEmpty else { return }
        if !address.contains("://") { address = "https://" + address }
        guard let url = URL(string: address), url.host != nil else { return }
        model.settings.customLinks.append(SchoolLink(title: title, url: url))
    }
}
