import SwiftUI

/// The tip jar: three consumables, one screen under Mehr, never a popup.
/// Tips unlock nothing that matters — the "Unterstützer" icon is a thank
/// you, not a feature — so nobody feels pushed.
struct SupportView: View {
    @Environment(Store.self) private var store

    private struct Tip: Identifiable {
        let id: ProductID
        let emoji: String
        let title: String
        /// Shown until StoreKit has answered; the real price always wins.
        let fallback: String
    }

    private let tips: [Tip] = [
        Tip(id: .tipSmall, emoji: "☕️", title: "Kaffee", fallback: "1,99 €"),
        Tip(id: .tipMedium, emoji: "🥪", title: "Mittagessen", fallback: "4,99 €"),
        Tip(id: .tipLarge, emoji: "🍝", title: "Mensa-Woche", fallback: "9,99 €")
    ]

    var body: some View {
        Form {
            Section {
                Text("Kein Abo, keine Werbung, kein Tracking. Die App bleibt kostenlos — wer mag, gibt einen Kaffee aus. Das deckt den Entwickler-Account und die Zeit für die nächste Version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(tips) { tip in
                    Button {
                        Task { await store.purchase(tip.id) }
                    } label: {
                        HStack {
                            Text(tip.emoji).font(.title2)
                            Text(tip.title)
                            Spacer()
                            if store.purchaseInFlight == tip.id {
                                ProgressView()
                            } else {
                                Text(store.product(tip.id)?.displayPrice ?? tip.fallback)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .tint(.primary)
                    .disabled(store.purchaseInFlight != nil)
                }
            } header: {
                Text("Trinkgeld")
            } footer: {
                if let message = store.lastErrorMessage {
                    Text(message)
                } else {
                    Text("Einmalig, ohne Gegenleistung — außer einem Dankeschön und dem „Unterstützer“-Symbol unter App-Symbol.")
                }
            }

            if store.entitlements.hasTipped {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .font(.title2)
                            .symbolEffect(.bounce, value: store.justTipped)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Danke fürs Unterstützen!").font(.headline)
                            Text("Das „Unterstützer“-Symbol ist jetzt freigeschaltet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("App unterstützen")
        .task { await store.loadProducts() }
    }
}
