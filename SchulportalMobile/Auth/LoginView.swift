import SwiftUI

/// Sign-in happens on the portal's own page inside a web view.
///
/// That is deliberate: the app never sees the password, and SSO, 2FA and the
/// school specific identity providers all keep working without us having to
/// reimplement the handshake. Afterwards the session cookies are copied into
/// `URLSession` and everything else is native.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingPortalLogin = false
    @State private var schoolID: String = ""

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
        .onAppear { schoolID = model.settings.schoolID }
        .fullScreenCover(isPresented: $isShowingPortalLogin) {
            LoginWebSheet(schoolID: schoolID.trimmingCharacters(in: .whitespaces)) {
                model.settings.schoolID = schoolID.trimmingCharacters(in: .whitespaces)
                isShowingPortalLogin = false
                Task { await model.didSignIn() }
            }
        }
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
                       detail: "Nachrichten & Co. öffnen sich im Tab „Portal“ – im gleichen mobilen Design.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var signInBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schulnummer (optional)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("z. B. 5182", text: $schoolID)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Text("Wenn du sie einträgst, ist deine Schule beim Anmelden schon ausgewählt. Du findest sie in der Adresszeile des Portals als „?i=…“.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isShowingPortalLogin = true
            } label: {
                Label("Am Schulportal anmelden", systemImage: "lock.open.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var privacyNote: some View {
        Text("Die Anmeldung läuft auf der Originalseite des Schulportals. Die App speichert kein Passwort – nur die Sitzung, damit sie deine Daten laden kann.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
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
