import XCTest
@testable import SchulportalMobile

/// Alternate icons only work when the asset catalog, the build setting and
/// the catalogue in code agree. The test host is the real app bundle, so its
/// Info.plist is the truth about what the build actually registered.
final class AppIconCatalogTests: XCTestCase {

    private var registeredAlternateIcons: Set<String> {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any]
        return Set((alternates ?? [:]).keys)
    }

    private var everyCatalogueIcon: [AppIconOption] {
        AppIconCatalog.paidPacks.flatMap(\.icons) + [AppIconCatalog.supporter]
    }

    func testPrimaryIconHasNoAssetName() {
        XCTAssertNil(AppIconCatalog.primary.assetName)
        XCTAssertEqual(AppIconCatalog.primary.id, "primary")
    }

    func testEveryCatalogueIconIsRegisteredInTheBuild() {
        let registered = registeredAlternateIcons
        XCTAssertFalse(registered.isEmpty, "the test host must be the real app with alternate icons")
        for option in everyCatalogueIcon {
            let name = try! XCTUnwrap(option.assetName, "\(option.title) needs an asset name")
            XCTAssertTrue(registered.contains(name), "\(name) is in the catalogue but not in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES")
        }
    }

    func testSchoolIconsInTheRegistryAreRegisteredInTheBuild() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "schools", withExtension: "json"))
        let registry = try JSONDecoder().decode([String: SchoolConfig].self, from: Data(contentsOf: url))
        let registered = registeredAlternateIcons
        for (number, config) in registry {
            guard let icon = config.iconName else { continue }
            XCTAssertTrue(registered.contains(icon), "school \(number) points at icon \(icon), which the build does not ship")
        }
    }

    func testIconIDsAreUnique() {
        let ids = everyCatalogueIcon.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate icon ids: \(ids)")
    }

    func testSchoolIconFollowsTheRegistryEntry() {
        XCTAssertNil(AppIconCatalog.schoolIcon(for: nil, schoolName: "Irgendeine Schule"))
        XCTAssertNil(AppIconCatalog.schoolIcon(for: SchoolConfig(), schoolName: "Irgendeine Schule"), "no iconName, no school icon")

        var config = SchoolConfig()
        config.iconName = "AppIconEli"
        config.name = "Elisabethenschule Frankfurt"
        let icon = AppIconCatalog.schoolIcon(for: config, schoolName: "")
        XCTAssertEqual(icon?.assetName, "AppIconEli")
        XCTAssertEqual(icon?.title, "Elisabethenschule Frankfurt")

        config.name = nil
        XCTAssertEqual(AppIconCatalog.schoolIcon(for: config, schoolName: "Meine")?.title, "Meine")
        XCTAssertEqual(AppIconCatalog.schoolIcon(for: config, schoolName: "")?.title, "Meine Schule")
    }

    func testSupporterIconIsNotForSale() {
        XCTAssertFalse(AppIconCatalog.paidPacks.contains { pack in pack.icons.contains { $0.id == AppIconCatalog.supporter.id } })
    }
}
