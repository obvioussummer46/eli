import XCTest
@testable import SchulportalMobile

/// The product-to-entitlement mapping is the one place a typo would sell
/// the wrong thing, so every product id is pinned here.
final class EntitlementsTests: XCTestCase {

    func testProductIDsAreTheAppStoreConnectIDs() {
        XCTAssertEqual(ProductID.iconsClassic.rawValue, "de.schulportalmobile.app.icons.classic")
        XCTAssertEqual(ProductID.iconsSeasonal.rawValue, "de.schulportalmobile.app.icons.seasonal")
        XCTAssertEqual(ProductID.iconsStyles1.rawValue, "de.schulportalmobile.app.icons.styles1")
        XCTAssertEqual(ProductID.iconsStyles2.rawValue, "de.schulportalmobile.app.icons.styles2")
        XCTAssertEqual(ProductID.proLifetime.rawValue, "de.schulportalmobile.app.pro.lifetime")
        XCTAssertEqual(ProductID.proYearly.rawValue, "de.schulportalmobile.app.pro.yearly")
    }

    /// Retired before the first paid build: the tip jar and the widget pack.
    /// Their ids must never come back under a different meaning.
    func testRetiredProductsStayRetired() {
        for id in ProductID.allCases {
            XCTAssertFalse(id.rawValue.contains(".tip."), "\(id) looks like a tip")
            XCTAssertFalse(id.rawValue.contains(".widgets."), "\(id) looks like the widget pack")
        }
    }

    func testProIsLifetimeOrYearly() {
        XCTAssertEqual(ProductID.allCases.filter(\.isPro), [.proLifetime, .proYearly])
    }

    func testIconPackIDsMatchTheCatalogue() {
        XCTAssertEqual(ProductID.iconsClassic.iconPackID, AppIconCatalog.classic.id)
        XCTAssertEqual(ProductID.iconsStyles1.iconPackID, AppIconCatalog.styles1.id)
        XCTAssertEqual(ProductID.iconsStyles2.iconPackID, AppIconCatalog.styles2.id)
        XCTAssertEqual(ProductID.iconsSeasonal.iconPackID, AppIconCatalog.seasonal.id)
        let iconProducts: Set<ProductID> = [.iconsClassic, .iconsStyles1, .iconsStyles2, .iconsSeasonal]
        for id in ProductID.allCases where !iconProducts.contains(id) {
            XCTAssertNil(id.iconPackID, "\(id) must not unlock an icon pack")
        }
    }

    func testEveryPaidPackHasAProductThatUnlocksIt() {
        for pack in AppIconCatalog.paidPacks {
            XCTAssertEqual(pack.productID?.iconPackID, pack.id, "pack \(pack.id) is not purchasable")
        }
    }

    func testFreeUserOwnsNothing() {
        let free = Entitlements()
        XCTAssertFalse(free.isPro)
        XCTAssertFalse(free.unlocksPremiumWidgets)
        XCTAssertFalse(free.owns(iconPack: "classic"))
        XCTAssertFalse(free.owns(iconPack: "seasonal"))
    }

    func testProOwnsEveryPackAndTheWidgets() {
        var pro = Entitlements()
        pro.isPro = true
        XCTAssertTrue(pro.unlocksPremiumWidgets)
        for pack in AppIconCatalog.paidPacks {
            XCTAssertTrue(pro.owns(iconPack: pack.id), "Pro must unlock \(pack.id)")
        }
    }

    func testSinglePackUnlocksOnlyItself() {
        var classic = Entitlements()
        classic.ownedIconPacks = ["classic"]
        XCTAssertTrue(classic.owns(iconPack: "classic"))
        XCTAssertFalse(classic.owns(iconPack: "seasonal"))
        XCTAssertFalse(classic.unlocksPremiumWidgets)
    }

    func testOnlyProUnlocksTheWidgets() {
        var everyPack = Entitlements()
        everyPack.ownedIconPacks = Set(AppIconCatalog.paidPacks.map(\.id))
        XCTAssertFalse(everyPack.unlocksPremiumWidgets)
    }

    /// An `entitlements.json` written by a build that still sold the widget
    /// pack and the tips must load; the retired flags are simply dropped.
    func testOlderFilesWithRetiredFlagsStillDecode() throws {
        let json = #"{"isPro":false,"hasWidgetPack":true,"ownedIconPacks":["classic"],"hasTipped":true}"#
        let decoded = try JSONDecoder().decode(Entitlements.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.isPro)
        XCTAssertFalse(decoded.unlocksPremiumWidgets)
        XCTAssertEqual(decoded.ownedIconPacks, ["classic"])
    }

    func testEntitlementsRoundTripThroughJSON() throws {
        var original = Entitlements()
        original.isPro = true
        original.ownedIconPacks = ["seasonal"]
        original.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Entitlements.self, from: encoder.encode(original))
        XCTAssertEqual(decoded, original)
    }
}
