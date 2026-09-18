import Foundation
import WidgetKit

/// Every product the app sells, by App Store Connect product id. The ids are
/// the one thing that can never change once a product is live, so they are
/// spelled out here once and nowhere else.
enum ProductID: String, CaseIterable {
    case iconsClassic = "de.schulportalmobile.app.icons.classic"
    case iconsSeasonal = "de.schulportalmobile.app.icons.seasonal"
    case iconsStyles1 = "de.schulportalmobile.app.icons.styles1"
    case iconsStyles2 = "de.schulportalmobile.app.icons.styles2"
    case proLifetime = "de.schulportalmobile.app.pro.lifetime"
    case proYearly = "de.schulportalmobile.app.pro.yearly"

    var isPro: Bool { self == .proLifetime || self == .proYearly }

    /// The icon pack this product unlocks, as `Entitlements.ownedIconPacks`
    /// spells it.
    var iconPackID: String? {
        switch self {
        case .iconsClassic: "classic"
        case .iconsSeasonal: "seasonal"
        case .iconsStyles1: "styles1"
        case .iconsStyles2: "styles2"
        default: nil
        }
    }
}

/// What the user has paid for, reduced to the flags the UI and the widgets
/// actually branch on. Written by the app after every StoreKit check, read
/// by the widget extension — which has no StoreKit of its own and must never
/// need one.
///
/// Two lanes only: Pro (yearly or lifetime) unlocks every feature and every
/// icon pack, current and future; a single icon pack unlocks itself. There
/// is no third thing to explain — the widget pack and the tip jar were
/// retired before the first paid build, see `Docs/MONETIZATION.md`.
struct Entitlements: Codable, Equatable {
    var isPro = false
    var ownedIconPacks: Set<String> = []
    var updatedAt: Date?

    /// The premium widgets are a Pro feature, nothing else sells them.
    var unlocksPremiumWidgets: Bool { isPro }

    func owns(iconPack id: String) -> Bool {
        isPro || ownedIconPacks.contains(id)
    }
}

/// Atomic JSON in the App Group container, next to the widget snapshot —
/// the same degrade-silently contract: no container, no entitlements, the
/// free app keeps working. Older files may carry keys from retired products
/// (`hasWidgetPack`, `hasTipped`); `Codable` ignores them.
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
