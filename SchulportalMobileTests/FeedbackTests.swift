import XCTest
@testable import SchulportalMobile

/// The feedback mail must arrive triageable: the right address, a subject
/// that sorts, and the install facts in the body — and it must survive
/// `mailto:` encoding with its line breaks intact.
final class FeedbackTests: XCTestCase {

    private let eli = Feedback.Context(
        schoolID: "5102", schoolName: "Elisabethenschule Frankfurt", schoolIsInRegistry: true,
        appVersion: "1.0", buildNumber: "7", systemVersion: "26.0", deviceModel: "iPhone15,2")

    private let unknown = Feedback.Context(
        schoolID: "6203", schoolName: "", schoolIsInRegistry: false,
        appVersion: "1.0", buildNumber: "7", systemVersion: "26.0", deviceModel: "iPad13,16")

    func testBodyCarriesTheInstallFacts() {
        let body = Feedback.body(for: .general, context: eli)
        XCTAssertTrue(body.contains("Schule: Elisabethenschule Frankfurt (Schulnummer 5102)"))
        XCTAssertTrue(body.contains("In der App eingetragen: ja"))
        XCTAssertTrue(body.contains("App: 1.0 (7)"))
        XCTAssertTrue(body.contains("iOS: 26.0, iPhone15,2"))
    }

    func testMissingSchoolAsksForWhatTheRegistryNeeds() {
        let body = Feedback.body(for: .missingSchool, context: unknown)
        XCTAssertTrue(body.contains("Schule: unbekannt (Schulnummer 6203)"))
        XCTAssertTrue(body.contains("In der App eingetragen: nein"))
        XCTAssertTrue(body.contains("menuebestellung.de"))
        XCTAssertTrue(body.contains("Website der Schule"))
    }

    func testMailURLTargetsTheAddressWithSubjectAndBody() throws {
        let url = try XCTUnwrap(Feedback.mailURL(for: .general, context: eli))
        XCTAssertEqual(url.scheme, "mailto")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "catchr@icloud.com")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["subject"], "Feedback zu Ranzen (Schulportal-App)")
        XCTAssertEqual(items["body"], Feedback.body(for: .general, context: eli))
    }

    func testMailURLEncodesLineBreaksAndPlusSigns() throws {
        let url = try XCTUnwrap(Feedback.mailURL(for: .missingSchool, context: unknown))
        let raw = url.absoluteString
        XCTAssertFalse(raw.contains("\n"))
        XCTAssertFalse(raw.contains("+"), "a literal + reads as a space in mailto bodies")
        XCTAssertTrue(raw.contains("%0A"))
        XCTAssertTrue(raw.hasPrefix("mailto:catchr@icloud.com?"))
    }
}
