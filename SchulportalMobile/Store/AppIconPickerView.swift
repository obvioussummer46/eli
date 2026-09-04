import SwiftUI
import UIKit

/// App-Symbol: the free ones, the school's own, the tip thank-you, and the
/// paid packs — every pack visible, locked ones one tap from the paywall.
struct AppIconPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(Store.self) private var store
    @State private var current: String? = UIApplication.shared.alternateIconName
    @State private var isShowingPaywall = false
    @State private var purchasingPack: String?

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        Form {
            Section {
                grid([AppIconCatalog.primary])
            } footer: {
                Text("Das Symbol wechselt sofort; iOS bestätigt das mit einem kurzen Hinweis.")
            }

            if let school = AppIconCatalog.schoolIcon(for: model.settings.registryConfig, schoolName: model.settings.schoolName) {
                Section {
                    grid([school])
                } header: {
                    Text("Meine Schule")
                } footer: {
                    Text("Ein eigenes Design in den Schulfarben — kostenlos für alle an dieser Schule.")
                }
            }

            ForEach(AppIconCatalog.paidPacks) { pack in
                let owned = store.entitlements.owns(iconPack: pack.id)
                Section {
                    grid(pack.icons, locked: !owned)
                    if !owned {
                        unlockRow(pack)
                    }
                } header: {
                    HStack {
                        Text(pack.title)
                        if !owned { ProBadge() }
                    }
                } footer: {
                    Text(pack.footer)
                }
            }

            Section {
                grid([AppIconCatalog.supporter], locked: !store.entitlements.hasTipped)
                if !store.entitlements.hasTipped {
                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("Mit einem Trinkgeld freischalten", systemImage: "heart")
                    }
                }
            } header: {
                Text("Unterstützer")
            } footer: {
                Text("Das Dankeschön für jedes Trinkgeld, egal wie klein.")
            }
        }
        .navigationTitle("App-Symbol")
        .paywall(isPresented: $isShowingPaywall)
        .task { await store.loadProducts() }
    }

    private func grid(_ options: [AppIconOption], locked: Bool = false) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(options) { option in
                Button {
                    select(option, locked: locked)
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            AppIconTile(option: option)
                                .opacity(locked ? 0.55 : 1)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .padding(4)
                                    .background(.thinMaterial, in: .circle)
                                    .offset(x: 4, y: 4)
                            } else if current == option.assetName {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.white, Color.accentColor)
                                    .offset(x: 6, y: 6)
                            }
                        }
                        Text(option.title)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func unlockRow(_ pack: AppIconPack) -> some View {
        Button {
            guard let productID = pack.productID else { return }
            purchasingPack = pack.id
            Task {
                await store.purchase(productID)
                purchasingPack = nil
            }
        } label: {
            HStack {
                Label("Paket freischalten", systemImage: "cart")
                Spacer()
                if purchasingPack == pack.id {
                    ProgressView()
                } else if let productID = pack.productID, let product = store.product(productID) {
                    Text(product.displayPrice).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .disabled(store.purchaseInFlight != nil)
        Button {
            isShowingPaywall = true
        } label: {
            Label("Oder alle Symbole mit \(Brand.pro)", systemImage: "sparkles")
        }
        .tint(.primary)
    }

    private func select(_ option: AppIconOption, locked: Bool) {
        if locked {
            if option.id == AppIconCatalog.supporter.id { return }
            isShowingPaywall = true
            return
        }
        guard current != option.assetName, UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.assetName)
        current = option.assetName
    }
}
