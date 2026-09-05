import XCTest
@testable import SchulportalMobile

/// The snapshot is what the widgets, Siri and the evening digest read, so its
/// date arithmetic has to be right in Europe/Berlin regardless of the
/// machine running the tests.
final class SharedSnapshotTests: XCTestCase {
    private let cal = SharedSnapshot.calendar

    /// A Berlin-local date; `hour` and `minute` default to noon.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private let mathe = SharedLesson(startMinutes: 8 * 60 + 10, endMinutes: 9 * 60 + 40, subject: "Mathematik", room: "2.16", colorHex: "#0040dd")
    private let deutsch = SharedLesson(startMinutes: 10 * 60, endMinutes: 11 * 60 + 30, subject: "Deutsch", room: nil, colorHex: "#d70015")

    /// Monday and Wednesday have lessons, the rest of the week is empty.
    private var weekSnapshot: SharedSnapshot {
        var snapshot = SharedSnapshot()
        snapshot.weekdayLessons = [1: [mathe, deutsch], 3: [mathe]]
        return snapshot
    }

    // MARK: - Lessons and weekdays

    func testLessonsUseMondayFirstNumbering() {
        let snapshot = weekSnapshot
        XCTAssertEqual(snapshot.lessons(on: date(2026, 9, 7)).map(\.subject), ["Mathematik", "Deutsch"], "Monday is 1")
        XCTAssertEqual(snapshot.lessons(on: date(2026, 9, 9)).map(\.subject), ["Mathematik"], "Wednesday is 3")
        XCTAssertTrue(snapshot.lessons(on: date(2026, 9, 6)).isEmpty, "Sunday is 7, not Calendar's 1")
    }

    func testNextSchoolDaySkipsTheWeekend() {
        let friday = date(2026, 9, 4)
        let next = weekSnapshot.nextSchoolDay(after: friday)
        XCTAssertNotNil(next)
        XCTAssertTrue(cal.isDate(next!, inSameDayAs: date(2026, 9, 7)))
    }

    func testNextSchoolDaySkipsEmptyWeekdays() {
        let monday = date(2026, 9, 7)
        let next = weekSnapshot.nextSchoolDay(after: monday)
        XCTAssertTrue(cal.isDate(next!, inSameDayAs: date(2026, 9, 9)), "Tuesday has no lessons, Wednesday does")
    }

    func testWeekendPauseIsSaturdayWithoutLessons() {
        let snapshot = weekSnapshot
        XCTAssertTrue(snapshot.isWeekendPause(at: date(2026, 9, 5)), "Saturday")
        XCTAssertTrue(snapshot.isWeekendPause(at: date(2026, 9, 5, 23, 30)), "still Saturday in Berlin")
        XCTAssertFalse(snapshot.isWeekendPause(at: date(2026, 9, 6)), "Sunday rolls over to Monday as usual")
        XCTAssertFalse(snapshot.isWeekendPause(at: date(2026, 9, 4)), "Friday")

        var saturdaySchool = snapshot
        saturdaySchool.weekdayLessons[6] = [mathe]
        XCTAssertFalse(saturdaySchool.isWeekendPause(at: date(2026, 9, 5)), "a school with Saturday lessons has no weekend pause")
    }

    func testNextSchoolDayIsNilWithoutAnyLessons() {
        XCTAssertNil(SharedSnapshot().nextSchoolDay(after: date(2026, 9, 4)))
    }

    func testCurrentOrNextLesson() {
        let snapshot = weekSnapshot
        let monday = { (h: Int, m: Int) in self.date(2026, 9, 7, h, m) }
        XCTAssertEqual(snapshot.currentOrNextLesson(at: monday(7, 30))?.subject, "Mathematik", "before school: the first lesson")
        XCTAssertEqual(snapshot.currentOrNextLesson(at: monday(8, 10))?.subject, "Mathematik", "start minute counts as ongoing")
        XCTAssertEqual(snapshot.currentOrNextLesson(at: monday(9, 40))?.subject, "Deutsch", "end minute is already the next lesson")
        XCTAssertEqual(snapshot.currentOrNextLesson(at: monday(9, 50))?.subject, "Deutsch", "the gap belongs to the next lesson")
        XCTAssertNil(snapshot.currentOrNextLesson(at: monday(12, 0)), "after the last lesson: nothing")
    }

    func testLessonLabelsPadToTwoDigits() {
        XCTAssertEqual(mathe.startLabel, "08:10")
        XCTAssertEqual(mathe.endLabel, "09:40")
        XCTAssertEqual(SharedLesson.label(0), "00:00")
        XCTAssertEqual(SharedLesson.label(13 * 60 + 5), "13:05")
    }

    // MARK: - Deadlines, substitutions, dishes

    func testDeadlineSubjectsAreDeduplicatedAndSorted() {
        var snapshot = SharedSnapshot()
        let monday = date(2026, 9, 7)
        snapshot.deadlines = [
            SharedDeadline(date: monday, subject: "Mathematik"),
            SharedDeadline(date: monday, subject: "Deutsch"),
            SharedDeadline(date: monday, subject: "Mathematik"),
            SharedDeadline(date: date(2026, 9, 8), subject: "Englisch")
        ]
        XCTAssertEqual(snapshot.deadlineSubjects(on: monday), ["Deutsch", "Mathematik"])
        XCTAssertEqual(snapshot.deadlineSubjects(on: date(2026, 9, 8)), ["Englisch"])
        XCTAssertTrue(snapshot.deadlineSubjects(on: date(2026, 9, 9)).isEmpty)
    }

    func testSubstitutionsAreFilteredByDay() {
        var snapshot = SharedSnapshot()
        let monday = date(2026, 9, 7)
        snapshot.substitutions = [
            SharedSubstitution(date: monday, period: "3", kind: "Entfall", subject: "Mathematik", summary: "3. Std. Mathematik entfällt"),
            SharedSubstitution(date: date(2026, 9, 8), period: "1", kind: "Vertretung", subject: "Deutsch", summary: "1. Std. Deutsch: Vertretung")
        ]
        XCTAssertEqual(snapshot.substitutions(on: monday).map(\.period), ["3"])
        XCTAssertEqual(snapshot.substitutions(on: date(2026, 9, 7, 23, 59)).count, 1, "same day, any time")
    }

    func testOrderedDishIsKeyedByBerlinISODay() {
        var snapshot = SharedSnapshot()
        snapshot.orderedDishes = ["2026-09-07": "Spaghetti"]
        XCTAssertEqual(snapshot.orderedDish(on: date(2026, 9, 7, 0, 30)), "Spaghetti", "just after midnight in Berlin is still that day")
        XCTAssertNil(snapshot.orderedDish(on: date(2026, 9, 8)))
    }

    // MARK: - Homework (premium widget)

    func testOpenHomeworkHidesWidgetTicks() {
        var snapshot = SharedSnapshot()
        snapshot.homework = [
            SharedHomework(id: "a", subject: "Mathematik", colorHex: "#0040dd", text: "S. 42", deadline: date(2026, 9, 7)),
            SharedHomework(id: "b", subject: "Deutsch", colorHex: "#d70015", text: "Lesen", deadline: date(2026, 9, 7)),
            SharedHomework(id: "c", subject: "Englisch", colorHex: "#248a3d", text: "Vokabeln", deadline: nil)
        ]
        XCTAssertEqual(snapshot.openHomework(excluding: []).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(snapshot.openHomework(excluding: ["b"]).map(\.id), ["a", "c"])
        XCTAssertEqual(snapshot.homework(dueOn: date(2026, 9, 7), excluding: ["a"]).map(\.id), ["b"])
        XCTAssertTrue(snapshot.homework(dueOn: date(2026, 9, 8), excluding: []).isEmpty, "homework without a deadline is never due")
    }

    func testOpenHomeworkIsEmptyForOldSnapshots() {
        XCTAssertTrue(SharedSnapshot().openHomework(excluding: []).isEmpty)
    }

    // MARK: - Events (countdown widget)

    private func event(_ id: String, _ start: Date, holiday: Bool = false, exam: Bool = false) -> SharedEvent {
        SharedEvent(id: id, title: id, start: start, end: start, isAllDay: true, isExam: exam, isHoliday: holiday, colorHex: "#000000")
    }

    func testNextEventPicksTheSoonestMatchingAndSkipsThePast() {
        var snapshot = SharedSnapshot()
        let today = date(2026, 9, 4)
        snapshot.events = [
            event("past-holiday", date(2026, 8, 20), holiday: true),
            event("exam-later", date(2026, 9, 20), exam: true),
            event("exam-soon", date(2026, 9, 15), exam: true),
            event("holiday", date(2026, 10, 5), holiday: true),
            event("today-exam", date(2026, 9, 4, 8, 0), exam: true)
        ]
        XCTAssertEqual(snapshot.nextEvent(after: today, where: { $0.isHoliday })?.id, "holiday")
        XCTAssertEqual(snapshot.nextEvent(after: today, where: { $0.isExam })?.id, "today-exam", "an event earlier today still counts")
        XCTAssertEqual(snapshot.nextEvent(after: date(2026, 9, 5), where: { $0.isExam })?.id, "exam-soon")
        XCTAssertNil(snapshot.nextEvent(after: date(2026, 12, 1), where: { _ in true }))
    }

    func testDaysUntilCountsWholeBerlinDays() {
        let holiday = event("h", date(2026, 10, 5, 0, 0), holiday: true)
        XCTAssertEqual(SharedSnapshot.daysUntil(holiday, from: date(2026, 10, 5, 23, 0)), 0)
        XCTAssertEqual(SharedSnapshot.daysUntil(holiday, from: date(2026, 10, 4, 23, 59)), 1)
        XCTAssertEqual(SharedSnapshot.daysUntil(holiday, from: date(2026, 9, 4)), 31)
    }

    // MARK: - Compatibility

    func testSnapshotsWrittenBeforeThePremiumWidgetsStillDecode() throws {
        let json = """
        {"weekdayLessons":{"1":[{"startMinutes":490,"endMinutes":580,"subject":"Mathematik","colorHex":"#0040dd"}]},
         "substitutions":[],"deadlines":[],"orderedDishes":{}}
        """
        let snapshot = try JSONDecoder().decode(SharedSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.homework)
        XCTAssertNil(snapshot.events)
        XCTAssertNil(snapshot.openOrderDays)
        XCTAssertEqual(snapshot.lessons(on: date(2026, 9, 7)).first?.subject, "Mathematik")
    }

    func testWidgetLinksStayStable() {
        XCTAssertEqual(WidgetLink.paywall.absoluteString, "schulportalmobile://paywall")
        XCTAssertEqual(WidgetLink.aufgaben.absoluteString, "schulportalmobile://tab/aufgaben")
        XCTAssertEqual(WidgetLink.heute.host, "tab")
        XCTAssertEqual(WidgetLink.paywall.host, "paywall")
    }
}
