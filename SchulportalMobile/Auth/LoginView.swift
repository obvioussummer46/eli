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
    @State private var isShowingSchoolPicker = false
    @State private var schoolID: String = ""
    @State private var schoolName: String = ""

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
                       detail: "Nachrichten & Co. öffnen sich im Tab „Portal“ – im gleichen mobilen Design.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var signInBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schule (optional)")
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

            Text("Damit ist deine Schule beim Anmelden schon ausgewählt. Ohne sie fragt das Schulportal selbst danach.")
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
