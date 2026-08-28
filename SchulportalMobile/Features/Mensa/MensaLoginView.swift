import SwiftUI

/// Sign-in for `menuebestellung.de`.
///
/// Unlike the Schulportal — which is signed into on its own page inside a web
/// view — this site has nothing but a username/password API. The credentials
/// are verified against the site before they go into the Keychain, so a typo
/// never gets stored, and from then on the client re-signs in on its own.
struct MensaLoginView: View {
    @Environment(MensaModel.self) private var mensa
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 12) {
                    TextField("Benutzername", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .username)
                        .onSubmit { focus = .password }

                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .onSubmit { submit() }
                }
                .textFieldStyle(.roundedBorder)

                if let message = mensa.signInErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    if mensa.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Anmelden").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)

                privacyNote
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if username.isEmpty { username = mensa.account.username }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("Mensa & Guthaben")
                .font(.title2.bold())
            Text("Speiseplan der Woche und der Stand auf der Karte — aus deinem Konto bei menuebestellung.de.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var privacyNote: some View {
        VStack(spacing: 8) {
            Text("Benutzername und Passwort landen im iOS-Schlüsselbund deines Geräts, damit die App sich selbst wieder anmelden kann, wenn die Sitzung abläuft. Sie werden weder synchronisiert noch irgendwohin sonst geschickt.")
            Text("Die App liest nur — bestellt wird weiterhin auf menuebestellung.de.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    private var canSubmit: Bool {
        !mensa.isLoading
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let name = username.trimmingCharacters(in: .whitespaces)
        let secret = password
        Task {
            if await mensa.signIn(username: name, password: secret) {
                password = ""
            }
        }
    }
}
