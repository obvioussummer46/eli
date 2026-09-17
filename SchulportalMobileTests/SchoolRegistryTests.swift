import XCTest
@testable import SchulportalMobile

/// The registry is data the app fetches, so the two things that must never
/// happen are: a broken remote file taking a school's configuration away,
/// and a valid one failing to replace the bundled copy.
final class SchoolRegistryTests: XCTestCase {

    private let bundled: [String: SchoolConfig] = [
        "5102": SchoolConfig(name: "Elisabethenschule Frankfurt", mensaTenant: "asb-heserv", links: nil, iconName: "AppIconEli")
    ]

    func testDecodeAcceptsARegistryFile() throws {
        let data = Data(#"{"3816": {"name": "Mittelpunktschule Trebur", "mensaTenant": "mps-trebur"}}"#.utf8)
        let decoded = try XCTUnwrap(SchoolRegistry.decode(data))
        XCTAssertEqual(decoded["3816"]?.name, "Mittelpunktschule Trebur")
        XCTAssertEqual(decoded["3816"]?.mensaTenant, "mps-trebur")
        XCTAssertNil(decoded["3816"]?.links)
    }

    func testDecodeRejectsGarbageAndEmpty() {
        XCTAssertNil(SchoolRegistry.decode(Data("<html>404</html>".utf8)))
        XCTAssertNil(SchoolRegistry.decode(Data("{}".utf8)), "an empty registry is a broken deploy, not a decision")
        XCTAssertNil(SchoolRegistry.decode(Data("[]".utf8)))
    }

    func testMergeAddsRemoteSchoolsAndKeepsBundledOnes() {
        let remote: [String: SchoolConfig] = [
            "3816": SchoolConfig(name: "Mittelpunktschule Trebur", mensaTenant: nil, links: nil, iconName: nil)
        ]
        let merged = SchoolRegistry.merge(bundled: bundled, remote: remote)
        XCTAssertEqual(Set(merged.keys), ["5102", "3816"])
        XCTAssertEqual(merged["5102"]?.mensaTenant, "asb-heserv")
    }

    func testMergeLetsRemoteWinPerSchool() {
        let remote: [String: SchoolConfig] = [
            "5102": SchoolConfig(name: "Elisabethenschule Frankfurt", mensaTenant: "new-tenant", links: nil, iconName: "AppIconEli")
        ]
        let merged = SchoolRegistry.merge(bundled: bundled, remote: remote)
        XCTAssertEqual(merged["5102"]?.mensaTenant, "new-tenant")
    }

    func testReplaceReportsWhetherAnythingChanged() {
        let original = SchoolRegistry.knownSchoolIDs
        defer {
            // Leave the process-wide registry as the other tests expect it.
            var restore: [String: SchoolConfig] = [:]
            for id in original { restore[id] = SchoolRegistry.entry(for: id) }
            SchoolRegistry.replace(with: restore)
        }
        let first: [String: SchoolConfig] = [
            "3816": SchoolConfig(name: "Mittelpunktschule Trebur", mensaTenant: "mps-trebur", links: nil, iconName: nil)
        ]
        XCTAssertTrue(SchoolRegistry.replace(with: first))
        XCTAssertEqual(SchoolRegistry.entry(for: "3816")?.mensaTenant, "mps-trebur")
        XCTAssertFalse(SchoolRegistry.replace(with: first), "same content, no change")
        XCTAssertTrue(SchoolRegistry.replace(with: [:]))
        XCTAssertNil(SchoolRegistry.entry(for: "3816"))
    }
}
