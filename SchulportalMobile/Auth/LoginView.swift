import SwiftUI

/// Sign-in, two ways.
///
/// The native form is the everyday route: username + password are verified
/// against the portal and then stored in the Keychain (device-only), so the
/// app can sign itself back in when the short-lived SPH session dies —
/// exactly what the Essen tab already does for the mensa account.
///
/// The screen works like a messenger's onboarding: one pill for the school,
/// and only once a school is chosen do the login fields slide in — a child
/// is never shown more than the one thing to do next. Everything else —
/// what the app does, parent accounts, SSO, the raw school number, the
/// privacy story — lives behind one info link at the bottom.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingPortalLogin = false
    @State private var isShowingSchoolPicker = false
    @State private var isShowingInfo = false
    /// SwiftUI drops a presentation that starts while another sheet is still
    /// animating away, so the info sheet only *requests* the web login and
    /// `onDismiss` performs it.
    @State private var wantsPortalLoginAfterInfo = false
    @State private var schoolID: String = ""
    @State private var schoolName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var accountKind: AccountKind = .school
    @State private var isSigningIn = false
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    /// The portal's own "Login-Typ-Wahl": accounts issued by the school
    /// (pupils, teachers — the login carries the school number) versus
    /// self-registered Bildungsserver accounts ("ohne Schulbezug", typically
    /// parents — no school in the login at all).
    private enum AccountKind {
        case school
        case bildungsserver
    }

    /// What reveals the login fields. A Bildungsserver account needs no
    /// school, so switching to it in the info sheet opens the form too.
    private var hasSchool: Bool {
        !trimmedID.isEmpty || accountKind == .bildungsserver
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                schoolPill

                if hasSchool {
                    credentialFields
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                infoLink
                    .padding(.top, 16)
            }
            .padding(.horizontal, 28)
            .padding(.top, 72)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: hasSchool)
        }
        .background(Color(.systemBackground))
        .onAppear {
            schoolID = model.settings.schoolID
            schoolName = model.settings.schoolName
            if username.isEmpty { username = model.portalUsername ?? "" }
        }
        .sheet(isPresented: $isShowingSchoolPicker) {
            SchoolPickerView { school in
                schoolID = school.id
                schoolName = school.name
                // Straight into typing, like a messenger — but only after the
                // sheet is gone and the fields exist, or the focus is dropped.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    focus = .username
                }
            }
        }
        .sheet(isPresented: $isShowingInfo, onDismiss: {
            if wantsPortalLoginAfterInfo {
                wantsPortalLoginAfterInfo = false
                isShowingPortalLogin = true
            }
        }) {
            LoginInfoSheet(manualSchoolID: manualID,
                           isParentAccount: isParentAccount) {
                wantsPortalLoginAfterInfo = true
                isShowingInfo = false
            }
        }
        .fullScreenCover(isPresented: $isShowingPortalLogin) {
            LoginWebSheet(schoolID: trimmedID) {
                model.settings.schoolID = trimmedID
                // Empty whenever the number was typed rather than picked —
                // `manualID` keeps the two from ever naming different schools.
                model.settings.schoolName = schoolName
                isShowingPortalLogin = false
                Task { await model.didSignIn() }
            }
        }
    }

    private var trimmedID: String { schoolID.trimmingCharacters(in: .whitespaces) }

    /// The number typed by hand, which drops any name picked earlier — the two
    /// must never name different schools on screen.
    ///
    /// A binding rather than `onChange`, which fires on the *next* view update
    /// and would therefore also run for the picker's own assignment, wiping the
    /// name it had just set.
    private var manualID: Binding<String> {
        Binding(get: { schoolID },
                set: { schoolID = $0; schoolName = "" })
    }

    private var isParentAccount: Binding<Bool> {
        Binding(get: { accountKind == .bildungsserver },
                set: { accountKind = $0 ? .bildungsserver : .school })
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Willkommen!")
                .font(.title.bold())
            Text(hasSchool
                 ? "Und jetzt dein Login vom Schulportal."
                 : "Wähle zuerst deine Schule aus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 18)
    }

    private var schoolPill: some View {
        Button {
            isShowingSchoolPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasPickedSchool ? "checkmark.circle.fill" : "magnifyingglass")
                    .foregroundStyle(hasPickedSchool ? Color.green : Color.accentColor)
                Text(schoolPillTitle)
                    .foregroundStyle(hasPickedSchool ? Color.primary : Color.accentColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .pillField()
        }
        .buttonStyle(.plain)
    }

    private var hasPickedSchool: Bool { !trimmedID.isEmpty }

    private var schoolPillTitle: String {
        if !schoolName.isEmpty { return schoolName }
        // A number typed by hand in the info sheet has no name to show.
        if !trimmedID.isEmpty { return "Schulnummer \(trimmedID)" }
        return "Schule suchen"
    }

    private var credentialFields: some View {
        VStack(spacing: 14) {
            // Switched on from the info sheet; the way back stays in sight so
            // nobody is trapped in a mode they cannot see the origin of.
            if accountKind == .bildungsserver {
                HStack {
                    Label("Eltern-Konto (Bildungsserver)", systemImage: "person.2.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button("Schulkonto verwenden") { accountKind = .school }
                        .font(.footnote)
                }
                .padding(.horizontal, 6)
            }

            TextField(accountKind == .school ? "Benutzername (vorname.nachname)" : "Benutzername", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }
                .pillField()

            RevealablePasswordField("Passwort", text: $password, focus: $focus, focusValue: .password) {
                submitCredentials()
            }
            .pillField()

            if let message = model.signInErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }

            Button {
                submitCredentials()
            } label: {
                Group {
                    if isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Text("Anmelden").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!canSubmitCredentials)
            .padding(.top, 4)
        }
    }

    private var infoLink: some View {
        Button {
            isShowingInfo = true
        } label: {
            Label("Infos, Eltern-Konto & weitere Anmelde-Optionen", systemImage: "info.circle")
                .font(.footnote)
        }
        .disabled(isSigningIn)
    }

    private var canSubmitCredentials: Bool {
        !isSigningIn
            && (accountKind == .bildungsserver || !trimmedID.isEmpty)
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func submitCredentials() {
        guard canSubmitCredentials else { return }
        focus = nil
        // The pick becomes real now — before the request, not after. For a
        // Bildungsserver account the school is only the *school*, not part
        // of the login; the portal spells that as `i=-1`.
        model.settings.schoolID = trimmedID
        model.settings.schoolName = schoolName
        let loginID = accountKind == .school ? trimmedID : "-1"
        let name = username.trimmingCharacters(in: .whitespaces)
        let secret = password
        isSigningIn = true
        Task {
            if await model.signIn(username: name, password: secret, loginID: loginID) {
                password = ""
            }
            isSigningIn = false
        }
    }
}

/// The messenger-style pill every input on this screen wears.
private struct PillField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemBackground), in: .capsule)
    }
}

private extension View {
    func pillField() -> some View { modifier(PillField()) }
}

/// Everything the first screen no longer says: what the app does, the
/// less-common ways in, and where the password ends up.
private struct LoginInfoSheet: View {
    @Binding var manualSchoolID: String
    @Binding var isParentAccount: Bool
    /// The browser route for everything the form cannot do: SSO, 2FA, school
    /// specific identity providers. Presented by the login screen after this
    /// sheet is gone — see `wantsPortalLoginAfterInfo`.
    let onPortalLogin: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Was die App kann") {
                    FeatureRow(icon: "checkmark.circle.fill",
                               title: "Hausaufgaben",
                               detail: "Alle offenen Aufgaben aus „Mein Unterricht“ auf einer Liste – antippen und erledigt.")
                    FeatureRow(icon: "calendar",
                               title: "Stundenplan",
                               detail: "Als echte Termine in deinen iOS-Kalender, mit Raum und Lehrkraft.")
                    FeatureRow(icon: "safari",
                               title: "Rest des Portals",
                               detail: "Nachrichten & Co. öffnen sich im mobilen Design unter „Mehr“ › Portal.")
                }

                Section {
                    Toggle("Eltern-Konto (Bildungsserver)", isOn: $isParentAccount)
                    Button("Über die Portalseite anmelden (SSO / 2FA)") {
                        onPortalLogin()
                    }
                } header: {
                    Text("Andere Anmeldemöglichkeiten")
                } footer: {
                    Text("Eltern-Konten sind selbst registriert, „ohne Schulbezug“. Die Portalseite braucht es für SSO, 2FA und schuleigene Anmeldedienste — die App speichert dann kein Passwort.")
                }

                Section {
                    TextField("z. B. 5182", text: $manualSchoolID)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Schulnummer direkt eingeben")
                } footer: {
                    Text("Wer die Nummer schon kennt, muss die Schule nicht suchen.")
                }

                Section("Datenschutz") {
                    Text("Benutzername und Passwort landen im Schlüsselbund deines Geräts, damit die App sich selbst wieder anmelden kann, wenn die Sitzung abläuft. Sie werden weder synchronisiert noch irgendwohin sonst geschickt. Über die Portalseite geht es auch ganz ohne gespeichertes Passwort.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
