import SwiftUI

/// Find your school by name instead of by number.
///
/// The login page wants `?i=<Schulnummer>`, and asking a child to dig a number
/// out of a URL is a poor first screen. The portal publishes the same directory
/// its own picker uses, so the app searches it and keeps the number to itself.
///
/// Optional throughout: the sheet can always be dismissed, and login works
/// without a school — the portal then shows its own picker.
struct SchoolPickerView: View {
    /// Called with the school the user settled on.
    let onPick: (School) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var schools: [School] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Schulliste wird geladen …")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    EmptyStateView(icon: "wifi.exclamationmark",
                                   title: "Schulliste nicht geladen",
                                   message: errorMessage)
                    .overlay(alignment: .bottom) {
                        Button("Nochmal versuchen") { Task { await load() } }
                            .buttonStyle(.bordered)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Schule suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            // Two thousand schools in one scroll is not a browsing experience,
            // so an empty field asks rather than dumps the alphabet.
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                EmptyStateView(icon: "magnifyingglass",
                               title: "\(schools.count) Schulen",
                               message: "Tippe den Namen deiner Schule oder deinen Ort ein.")
                .listRowSeparator(.hidden)
            } else if results.isEmpty {
                EmptyStateView(icon: "questionmark.circle",
                               title: "Nichts gefunden",
                               message: "Prüfe die Schreibweise, oder suche nach dem Ort statt nach dem Namen.")
                .listRowSeparator(.hidden)
            } else {
                ForEach(results) { school in
                    Button {
                        onPick(school)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(school.name)
                                .foregroundStyle(.primary)
                            Text(school.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Name oder Ort")
        .autocorrectionDisabled()
    }

    /// Capped: past a few dozen hits the answer is "type more", and rendering
    /// two thousand rows to say so costs a visibly janky first keystroke.
    private var results: [School] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return Array(SchoolDirectory.search(query, in: schools).prefix(60))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            schools = try await SchoolDirectory.shared.all()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
