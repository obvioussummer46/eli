import XCTest
@testable import SchulportalMobile

/// The countdown widget and the Termine tab classify calendar entries by
/// their wording; these pin the German words that count.
final class SchoolEventTextTests: XCTestCase {

    func testHolidayStems() {
        XCTAssertTrue(SchoolEventText.mentionsHoliday("Herbstferien"))
        XCTAssertTrue(SchoolEventText.mentionsHoliday("Tag der Deutschen Einheit (Feiertag)"))
        XCTAssertTrue(SchoolEventText.mentionsHoliday("Beweglicher Ferientag"))
        XCTAssertTrue(SchoolEventText.mentionsHoliday("Unterrichtsfrei wegen Konferenz"))
        XCTAssertTrue(SchoolEventText.mentionsHoliday("SCHULFREI"))
        XCTAssertFalse(SchoolEventText.mentionsHoliday("Elternabend"))
        XCTAssertTrue(SchoolEventText.mentionsHoliday("Ferienbetreuung anmelden"), "any mention of Ferien counts, even a related one")
    }

    func testExamWordsMatchWholeWordsOnly() {
        XCTAssertTrue(SchoolEventText.mentionsExam("D 05A Arbeit"))
        XCTAssertTrue(SchoolEventText.mentionsExam("Klausur Q1"))
        XCTAssertTrue(SchoolEventText.mentionsExam("Test in Mathe"))
        XCTAssertTrue(SchoolEventText.mentionsExam("Lernkontrolle"))
        XCTAssertFalse(SchoolEventText.mentionsExam("Arbeitsgemeinschaft Theater"), "Arbeitsgemeinschaft is not an exam")
        XCTAssertFalse(SchoolEventText.mentionsExam("Testament lesen"))
        XCTAssertFalse(SchoolEventText.mentionsExam("Wandertag"))
    }

    func testExpandTurnsCourseCodesIntoSubjects() {
        XCTAssertEqual(SchoolEventText.expand("D 05A Arbeit"), "Deutsch-Arbeit")
        XCTAssertEqual(SchoolEventText.expand("M 7c Test"), "Mathematik-Test")
        XCTAssertEqual(SchoolEventText.expand("Arbeit in D 05A (051D01-GYM)"), "Arbeit in Deutsch (051D01-GYM)")
        XCTAssertEqual(SchoolEventText.expand("Elternabend"), "Elternabend", "text without a course code is untouched")
    }

    func testEventFlagsComeFromCategoryOrTitle() {
        let base = SchoolEvent(id: "1", title: "Irgendwas", description: "", place: nil, categoryName: nil,
                               colorHex: "#000000", start: Date(), end: Date(), isAllDay: true)
        XCTAssertFalse(base.isExam)
        XCTAssertFalse(base.isHoliday)

        var byCategory = base
        byCategory.categoryName = "Klausuren"
        XCTAssertTrue(byCategory.isExam)

        var byTitle = base
        byTitle.title = "Herbstferien"
        XCTAssertTrue(byTitle.isHoliday)
        XCTAssertFalse(byTitle.isExam)
    }
}
