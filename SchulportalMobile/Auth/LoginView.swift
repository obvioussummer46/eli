import SwiftUI

/// Sign-in, two ways.
///
/// The native form is the everyday route: username + password are verified
/// against the portal and then stored in the Keychain (device-only), so the
/// app can sign itself back in when the short-lived SPH session dies —
/// exactly what the Essen tab already does for the mensa account.
///
/// The browser route stays for everyone the form cannot serve: SSO, 2FA and
/// school specific identity providers all work on the portal's own page, and
/// the app then only ever holds the session cookie, never a password.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingPortalLogin = false
    @State private var isShowingSchoolPicker = false
    @State private var schoolID: String = ""
    @State private var schoolName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSigningIn = false
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    featureList
                    signInBox
                    privacyNote
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

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("Schulportal, aber fürs Handy")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Hausaufgaben abhaken, Stundenplan im iOS-Kalender.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var signInBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schule")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                isShowingSchoolPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schoolName.isEmpty ? "Schule suchen" : schoolName)
                            .foregroundStyle(schoolName.isEmpty ? Color.accentColor : Color.primary)
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

            // The number still works on its own: whoever already knows it
            // should not have to search for a name to get at it.
            DisclosureGroup("Schulnummer direkt eingeben") {
                TextField("z. B. 5182", text: manualID)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 6)
            }
            .font(.caption)
            .tint(.secondary)

            Text("Zugangsdaten")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            TextField("Benutzername (vorname.nachname)", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }
                .textFieldStyle(.roundedBorder)

            SecureField("Passwort", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onSubmit { submitCredentials() }
                .textFieldStyle(.roundedBorder)

            if let message = model.signInErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
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

            // The escape hatch for everything the form cannot do: SSO, 2FA,
            // school specific identity providers. It needs no school picked —
            // the portal then asks itself.
            Button("Über die Portalseite anmelden (SSO / 2FA)") {
                isShowingPortalLogin = true
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .disabled(isSigningIn)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var privacyNote: some View {
        Text("Benutzername und Passwort landen im Schlüsselbund deines Geräts, damit die App sich selbst wieder anmelden kann, wenn die Sitzung abläuft. Sie werden weder synchronisiert noch irgendwohin sonst geschickt. Über die Portalseite geht es auch ganz ohne gespeichertes Passwort.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private var canSubmitCredentials: Bool {
        !isSigningIn
            && !trimmedID.isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func submitCredentials() {
        guard canSubmitCredentials else { return }
        focus = nil
        // The form's POST wants the school number, so the pick becomes real
        // now — before the request, not after.
        model.settings.schoolID = trimmedID
        model.settings.schoolName = schoolName
        let name = username.trimmingCharacters(in: .whitespaces)
        let secret = password
        isSigningIn = true
        Task {
            if await model.signIn(username: name, password: secret) {
                password = ""
            }
            isSigningIn = false
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
