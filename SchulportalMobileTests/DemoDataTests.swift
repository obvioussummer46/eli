import XCTest
@testable import SchulportalMobile

/// The screenshot data set has to look like a real week: every school day
/// filled, an AG that does not collide with a lesson, homework the list can
/// sort, a mensa week the tab can show — and it must survive the same JSON
/// round trip the real snapshot takes.
final class DemoDataTests: XCTestCase {
    func testEverySchoolDayHasLessons() {
        let plan = DemoData.timetable
        for day in [Weekday.monday, .tuesday, .wednesday, .thursday, .friday] {
            XCTAssertFalse(plan.entries(on: day).isEmpty, "\(day.germanName) is empty")
        }
        XCTAssertTrue(plan.entries(on: .saturday).isEmpty)
    }

    func testActivitiesDoNotOverlapLessons() {
        let plan = DemoData.timetable
        for activity in DemoData.activities {
            for lesson in plan.entries(on: activity.weekday) {
                let overlaps = activity.start < lesson.end && lesson.start < activity.end
                XCTAssertFalse(overlaps, "\(activity.title) overlaps \(lesson.subject.name)")
            }
        }
    }

    func testHomeworkIsOpenAndUniquelyIdentified() {
        let homework = DemoData.entries.compactMap(\.homework)
        XCTAssertEqual(Set(homework.map(\.id)).count, homework.count)
        XCTAssertEqual(homework.filter { !$0.isDoneOnPortal }.count, 7)
        XCTAssertEqual(homework.filter(\.isDoneOnPortal).count, 3)
        // Two of them carry an explicit deadline the parser must find.
        XCTAssertEqual(homework.filter { $0.dueDate != nil }.count, 2)
    }

    func testSubstitutionsCoverTodayAndTomorrow() {
        let plan = DemoData.substitutions
        XCTAssertNotNil(plan.day(on: Date()))
        let tomorrow = GermanDate.calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertNotNil(plan.day(on: tomorrow))
    }

    func testMensaWeekIsAWorkingWeek() {
        let week = DemoData.mensaWeek
        XCTAssertEqual(week.days.map(\.id), ["MO", "DI", "MI", "DO", "FR"])
        XCTAssertTrue(week.days.allSatisfy { $0.date != nil && $0.options.count == 2 })
        XCTAssertEqual(week.days.compactMap(\.orderedOption).count, 4)
        XCTAssertEqual(DemoData.mensaAccount.balance, DemoData.mensaStatement.balance)
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let snapshot = DemoData.snapshot
        let data = try JSONEncoder.portal.encode(snapshot)
        let decoded = try JSONDecoder.portal.decode(Snapshot.self, from: data)
        XCTAssertEqual(decoded.courses, snapshot.courses)
        XCTAssertEqual(decoded.entries, snapshot.entries)
        // `fetchedAt` loses its sub-second part in ISO 8601; the plan itself must not.
        XCTAssertEqual(decoded.timetable.entries, snapshot.timetable.entries)
        XCTAssertEqual(decoded.timetable.periods, snapshot.timetable.periods)
        XCTAssertEqual(decoded.events, snapshot.events)
    }

    func testNothingRealLeaksIn() {
        // The registry's real school must not be the demo school, and no
        // real portal id shape (numeric course ids) may appear.
        XCTAssertNil(SchoolRegistry.entry(for: "0000"))
        XCTAssertTrue(DemoData.courses.allSatisfy { $0.id.hasPrefix("demo-") })
    }
}
