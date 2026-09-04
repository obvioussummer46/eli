import StoreKit
import SwiftUI

/// The one paywall. Lifetime first, yearly for people who refuse lifetime,
/// restore and the two legal links — nothing else. Every feature it lists
/// is a nice-to-have on top of an app that stays complete for free.
struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var trialLabel: String?

    private struct Feature: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private let features: [Feature] = [
        Feature(icon: "checklist", title: "Aufgaben-Widget", detail: "Hausaufgaben direkt auf dem Homescreen abhaken."),
        Feature(icon: "calendar.day.timeline.left", title: "Tagesplan-Widget", detail: "Der ganze Tag mit Vertretungen, groß."),
        Feature(icon: "hourglass", title: "Countdown-Widget", detail: "Tage bis zu den Ferien oder zur nächsten Arbeit — auch auf dem Sperrbildschirm."),
        Feature(icon: "paintpalette", title: "Alle App-Symbole", detail: "Jedes Symbol-Paket, auch die künftigen."),
        Feature(icon: "bell.badge", title: "Eigene Erinnerungszeiten", detail: "Aufgaben-Erinnerung und Abend-Überblick, wann du willst."),
        Feature(icon: "square.and.arrow.up", title: "Aufgaben exportieren", detail: "Als Text oder Tabelle teilen.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    featureList
                    if store.entitlements.isPro {
                        activeState
                    } else {
                        offers
                    }
                    legal
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
                trialLabel = await store.trialLabel(for: .proYearly)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("Mehr Widgets, mehr Symbole, mehr Ruhe.")
                .font(.title2.bold())
            Text("Die App bleibt kostenlos — Hausaufgaben, Stundenplan, Kalender, Mensa und die drei Widgets gehören allen. Pro ist das Extra obendrauf und finanziert die Weiterentwicklung.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.weight(.semibold))
                        Text(feature.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var offers: some View {
        VStack(spacing: 12) {
            if let lifetime = store.product(.proLifetime) {
                offerButton(id: .proLifetime,
                            title: "Einmal kaufen",
                            price: lifetime.displayPrice,
                            detail: "Für immer, mit Familienfreigabe.",
                            prominent: true)
            }
            if let yearly = store.product(.proYearly) {
                offerButton(id: .proYearly,
                            title: "Jährlich",
                            price: "\(yearly.displayPrice) / Jahr",
                            detail: trialLabel ?? "Jederzeit kündbar.",
                            prominent: false)
            }
            if store.products.isEmpty {
                if store.isLoadingProducts {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if let message = store.lastErrorMessage {
                    InlineErrorBanner(message: message) {
                        Task { await store.loadProducts() }
                    }
                }
            } else if let message = store.lastErrorMessage {
                InlineErrorBanner(message: message)
            }
            Button("Käufe wiederherstellen") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .padding(.top, 4)
        }
    }

    private func offerButton(id: ProductID, title: String, price: String, detail: String, prominent: Bool) -> some View {
        Button {
            Task {
                if await store.purchase(id) { dismiss() }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).opacity(0.85)
                }
                Spacer()
                if store.purchaseInFlight == id {
                    ProgressView()
                } else {
                    Text(price).font(.headline.monospacedDigit())
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? Color.accentColor : Color(.tertiarySystemFill))
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .disabled(store.purchaseInFlight != nil)
    }

    private var activeState: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro ist aktiv").font(.headline)
                Text("Danke! Alle Extras sind freigeschaltet.").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Das Jahresabo verlängert sich automatisch, bis es in den iOS-Einstellungen gekündigt wird. Der Betrag wird über deinen Apple-Account abgerechnet. Alle Käufe gelten mit Familienfreigabe.")
            HStack(spacing: 12) {
                Link("Nutzungsbedingungen", destination: StoreLinks.terms)
                Link("Datenschutz", destination: StoreLinks.privacy)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
