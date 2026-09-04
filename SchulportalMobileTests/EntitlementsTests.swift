import XCTest
@testable import SchulportalMobile

/// The product-to-entitlement mapping is the one place a typo would sell
/// the wrong thing, so every product id is pinned here.
final class EntitlementsTests: XCTestCase {

    func testProductIDsAreTheAppStoreConnectIDs() {
        XCTAssertEqual(ProductID.tipSmall.rawValue, "de.schulportalmobile.app.tip.small")
        XCTAssertEqual(ProductID.tipMedium.rawValue, "de.schulportalmobile.app.tip.medium")
        XCTAssertEqual(ProductID.tipLarge.rawValue, "de.schulportalmobile.app.tip.large")
        XCTAssertEqual(ProductID.widgetPack.rawValue, "de.schulportalmobile.app.widgets.pack")
        XCTAssertEqual(ProductID.iconsClassic.rawValue, "de.schulportalmobile.app.icons.classic")
        XCTAssertEqual(ProductID.iconsSeasonal.rawValue, "de.schulportalmobile.app.icons.seasonal")
        XCTAssertEqual(ProductID.proLifetime.rawValue, "de.schulportalmobile.app.pro.lifetime")
        XCTAssertEqual(ProductID.proYearly.rawValue, "de.schulportalmobile.app.pro.yearly")
    }

    func testTipsArePreciselyTheThreeConsumables() {
        XCTAssertEqual(ProductID.allCases.filter(\.isTip), [.tipSmall, .tipMedium, .tipLarge])
    }

    func testProIsLifetimeOrYearly() {
        XCTAssertEqual(ProductID.allCases.filter(\.isPro), [.proLifetime, .proYearly])
    }

    func testIconPackIDsMatchTheCatalogue() {
        XCTAssertEqual(ProductID.iconsClassic.iconPackID, AppIconCatalog.classic.id)
        XCTAssertEqual(ProductID.iconsSeasonal.iconPackID, AppIconCatalog.seasonal.id)
        for id in ProductID.allCases where id != .iconsClassic && id != .iconsSeasonal {
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

    func testWidgetPackUnlocksWidgetsButNoIcons() {
        var widgets = Entitlements()
        widgets.hasWidgetPack = true
        XCTAssertTrue(widgets.unlocksPremiumWidgets)
        XCTAssertFalse(widgets.owns(iconPack: "classic"))
    }

    func testTipIsNotAnEntitlement() {
        var tipped = Entitlements()
        tipped.hasTipped = true
        XCTAssertFalse(tipped.isPro)
        XCTAssertFalse(tipped.unlocksPremiumWidgets)
        XCTAssertFalse(tipped.owns(iconPack: "classic"))
    }

    func testEntitlementsRoundTripThroughJSON() throws {
        var original = Entitlements()
        original.isPro = true
        original.ownedIconPacks = ["seasonal"]
        original.hasTipped = true
        original.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Entitlements.self, from: encoder.encode(original))
        XCTAssertEqual(decoded, original)
    }
}
