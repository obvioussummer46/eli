import Foundation
import WidgetKit

/// Every product the app sells, by App Store Connect product id. The ids are
/// the one thing that can never change once a product is live, so they are
/// spelled out here once and nowhere else.
enum ProductID: String, CaseIterable {
    case tipSmall = "de.schulportalmobile.app.tip.small"
    case tipMedium = "de.schulportalmobile.app.tip.medium"
    case tipLarge = "de.schulportalmobile.app.tip.large"
    case widgetPack = "de.schulportalmobile.app.widgets.pack"
    case iconsClassic = "de.schulportalmobile.app.icons.classic"
    case iconsSeasonal = "de.schulportalmobile.app.icons.seasonal"
    case proLifetime = "de.schulportalmobile.app.pro.lifetime"
    case proYearly = "de.schulportalmobile.app.pro.yearly"

    var isTip: Bool {
        switch self {
        case .tipSmall, .tipMedium, .tipLarge: true
        default: false
        }
    }

    var isPro: Bool { self == .proLifetime || self == .proYearly }

    /// The icon pack this product unlocks, as `Entitlements.ownedIconPacks`
    /// spells it.
    var iconPackID: String? {
        switch self {
        case .iconsClassic: "classic"
        case .iconsSeasonal: "seasonal"
        default: nil
        }
    }
}

/// What the user has paid for, reduced to the flags the UI and the widgets
/// actually branch on. Written by the app after every StoreKit check, read
/// by the widget extension — which has no StoreKit of its own and must never
/// need one.
struct Entitlements: Codable, Equatable {
    var isPro = false
    var hasWidgetPack = false
    var ownedIconPacks: Set<String> = []
    /// Consumables never show up in `Transaction.currentEntitlements`, so
    /// the thank-you state is remembered here once and kept across refreshes.
    var hasTipped = false
    var updatedAt: Date?

    /// The premium widgets come with the widget pack *or* Pro.
    var unlocksPremiumWidgets: Bool { isPro || hasWidgetPack }

    func owns(iconPack id: String) -> Bool {
        isPro || ownedIconPacks.contains(id)
    }
}

/// Atomic JSON in the App Group container, next to the widget snapshot —
/// the same degrade-silently contract: no container, no entitlements, the
/// free app keeps working.
enum EntitlementStore {
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedSnapshotStore.appGroupID)?
            .appendingPathComponent("entitlements.json")
    }

    static func load() -> Entitlements {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return Entitlements() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Entitlements.self, from: data)) ?? Entitlements()
    }

    /// Saves and wakes every widget: a locked placeholder must turn into the
    /// real widget the moment the purchase goes through, without a relaunch.
    static func save(_ entitlements: Entitlements) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entitlements) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
