import SwiftUI

/// Sign-in, two ways.
///
/// The native form is the everyday route: username + password are verified
/// against the portal and then stored in the Keychain (device-only), so the
/// app can sign itself back in when the short-lived SPH session dies —
/// exactly what the Essen tab already does for the mensa account.
///
/// The first screen is deliberately three steps a child can follow: school,
/// name, password. Everything else — what the app does, parent accounts,
/// SSO, the raw school number, the privacy story — lives behind one info
/// link so it cannot get in the way of a first login.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    signInBox
                    infoLink
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Willkommen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            schoolID = model.settings.schoolID
            schoolName = model.settings.schoolName
            if username.isEmpty { username = model.portalUsername ?? "" }
        }
        .sheet(isPresented: $isShowingSchoolPicker) {
            SchoolPickerView { school in
                schoolID = school.id
                schoolName = school.name
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
        VStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("Schulportal, aber fürs Handy")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Melde dich mit deinem Schulportal-Zugang an — wie am Computer in der Schule.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var signInBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel(1, "Deine Schule")

            Button {
                isShowingSchoolPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schoolButtonTitle)
                            .foregroundStyle(schoolName.isEmpty && trimmedID.isEmpty
                                             ? Color.accentColor : Color.primary)
                            .multilineTextAlignment(.leading)
                        if !schoolName.isEmpty {
                            Text("Schulnummer \(schoolID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            stepLabel(2, "Dein Login")
                .padding(.top, 6)

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
            }

            TextField(accountKind == .school ? "Benutzername (vorname.nachname)" : "Benutzername", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }
                .textFieldStyle(.roundedBorder)

            RevealablePasswordField("Passwort", text: $password, focus: $focus, focusValue: .password) {
                submitCredentials()
            }
            .textFieldStyle(.roundedBorder)

            if let message = model.signInErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // The button quietly refusing to enable is worse than a sentence:
            // whoever typed name + password deserves to know what is missing.
            if accountKind == .school, trimmedID.isEmpty, !username.isEmpty, !password.isEmpty {
                Text("Wähle oben deine Schule aus — die Anmeldung mit einem Schulkonto braucht ihre Schulnummer.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                submitCredentials()
            } label: {
                if isSigningIn {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Anmelden", systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmitCredentials)
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var schoolButtonTitle: String {
        if !schoolName.isEmpty { return schoolName }
        // A number typed by hand in the info sheet has no name to show.
        if !trimmedID.isEmpty { return "Schulnummer \(trimmedID)" }
        return "Schule suchen"
    }

    private func stepLabel(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: .circle)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
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
