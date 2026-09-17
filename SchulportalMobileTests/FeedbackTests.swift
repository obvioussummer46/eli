import XCTest
@testable import SchulportalMobile

/// The feedback mail must arrive triageable: the right address, a subject
/// that sorts, and the install facts in the body — and it must survive
/// `mailto:` encoding with its line breaks intact.
final class FeedbackTests: XCTestCase {

    private let eli = Feedback.Context(
        schoolID: "5102", schoolName: "Elisabethenschule Frankfurt", hasSchoolProfile: true,
        appVersion: "1.0", buildNumber: "7", systemVersion: "26.0", deviceModel: "iPhone15,2")

    private let unknown = Feedback.Context(
        schoolID: "6203", schoolName: "", hasSchoolProfile: false,
        appVersion: "1.0", buildNumber: "7", systemVersion: "26.0", deviceModel: "iPad13,16")

    func testBodyCarriesTheInstallFacts() {
        let body = Feedback.body(for: .general, context: eli)
        XCTAssertTrue(body.contains("Schule: Elisabethenschule Frankfurt (Schulnummer 5102)"))
        XCTAssertTrue(body.contains("Schulprofil hinterlegt: ja"))
        XCTAssertTrue(body.contains("App: 1.0 (7)"))
        XCTAssertTrue(body.contains("iOS: 26.0, iPhone15,2"))
    }

    func testSchoolProfileAsksForWhatTheRegistryNeeds() {
        let body = Feedback.body(for: .schoolProfile, context: unknown)
        XCTAssertTrue(body.contains("Schule: unbekannt (Schulnummer 6203)"))
        XCTAssertTrue(body.contains("Schulprofil hinterlegt: nein"))
        XCTAssertTrue(body.contains("menuebestellung.de"))
        XCTAssertTrue(body.contains("Website der Schule"))
    }

    /// The school is never "missing": it logs in and has a timetable like
    /// every other. The mail must say what is missing (a profile) and that
    /// every field is optional, or a beta tester reads it as a bug report.
    func testSchoolProfileMailNeverCallsTheSchoolMissing() {
        let body = Feedback.body(for: .schoolProfile, context: unknown)
        XCTAssertFalse(body.lowercased().contains("fehlt in der app"))
        XCTAssertFalse(Feedback.Kind.schoolProfile.subject.contains("fehlt"))
        XCTAssertTrue(body.contains("ist in der App"))
        XCTAssertTrue(body.contains("(optional)"))
        XCTAssertTrue(body.contains("freiwillig"))
    }

    func testMailURLTargetsTheAddressWithSubjectAndBody() throws {
        let url = try XCTUnwrap(Feedback.mailURL(for: .general, context: eli))
        XCTAssertEqual(url.scheme, "mailto")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, Feedback.address)
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["subject"], "Feedback zu Ranzen (Schulportal-App)")
        XCTAssertEqual(items["body"], Feedback.body(for: .general, context: eli))
    }

    func testMailURLEncodesLineBreaksAndPlusSigns() throws {
        let url = try XCTUnwrap(Feedback.mailURL(for: .schoolProfile, context: unknown))
        let raw = url.absoluteString
        XCTAssertFalse(raw.contains("\n"))
        XCTAssertFalse(raw.contains("+"), "a literal + reads as a space in mailto bodies")
        XCTAssertTrue(raw.contains("%0A"))
        XCTAssertTrue(raw.hasPrefix("mailto:\(Feedback.address)?"))
    }
}
