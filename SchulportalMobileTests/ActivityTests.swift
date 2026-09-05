import XCTest
@testable import SchulportalMobile

/// User-entered AGs are merged into the portal's timetable by their times;
/// these pin how they land in the period grid and in the day's order.
final class ActivityTests: XCTestCase {
    private func time(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m) }

    private func lesson(_ day: Weekday, _ first: Int, _ last: Int, _ start: TimeOfDay, _ end: TimeOfDay, _ name: String) -> TimetableEntry {
        TimetableEntry(id: "\(day.rawValue)-\(first)-\(name)", weekday: day, firstPeriod: first, lastPeriod: last,
                       start: start, end: end, rawTitle: name,
                       subject: Subject(code: String(name.prefix(1)), name: name, colorHex: "#000000"),
                       room: nil, teacher: nil)
    }

    /// Eli-style day: eight periods, a double lesson in 3–4, nothing after 14:55.
    private var portalPlan: Timetable {
        var plan = Timetable()
        plan.periods = [
            Period(index: 1, start: time(8, 10), end: time(8, 55)),
            Period(index: 2, start: time(9, 0), end: time(9, 45)),
            Period(index: 3, start: time(10, 0), end: time(10, 45)),
            Period(index: 4, start: time(10, 45), end: time(11, 30)),
            Period(index: 5, start: time(11, 50), end: time(12, 35)),
            Period(index: 6, start: time(12, 35), end: time(13, 20)),
            Period(index: 7, start: time(13, 25), end: time(14, 10)),
            Period(index: 8, start: time(14, 10), end: time(14, 55))
        ]
        plan.entries = [
            lesson(.thursday, 1, 2, time(8, 10), time(9, 45), "Mathematik"),
            lesson(.thursday, 3, 4, time(10, 0), time(11, 30), "Deutsch"),
            lesson(.thursday, 7, 7, time(13, 25), time(14, 10), "Sport")
        ]
        return plan
    }

    func testNoActivitiesLeavesThePlanUntouched() {
        let plan = portalPlan
        XCTAssertEqual(plan.merging([]).entries, plan.entries)
    }

    func testActivityInAPeriodTakesThatPeriod() {
        let delf = SchoolActivity(title: "DELF", weekday: .thursday, start: time(14, 10), end: time(14, 55), room: "1.03")
        let merged = portalPlan.merging([delf])
        let entry = merged.entries(on: .thursday).last!
        XCTAssertEqual(entry.subject.name, "DELF")
        XCTAssertEqual(entry.firstPeriod, 8)
        XCTAssertEqual(entry.lastPeriod, 8, "ending exactly at 14:55 is still the 8th period")
        XCTAssertEqual(entry.room, "1.03")
        XCTAssertTrue(entry.isActivity)
        XCTAssertEqual(entry.activityID, delf.id)
        XCTAssertEqual(entry.id, "activity:" + delf.id)
    }

    func testActivitySpanningPeriodsSpansThem() {
        let chor = SchoolActivity(title: "Chor", weekday: .thursday, start: time(13, 25), end: time(14, 55))
        let entry = portalPlan.merging([chor]).entries(on: .thursday).last!
        XCTAssertEqual(entry.firstPeriod, 7)
        XCTAssertEqual(entry.lastPeriod, 8)
    }

    func testActivityAfterSchoolGetsTheNextFreePeriod() {
        let hort = SchoolActivity(title: "Hort", weekday: .thursday, start: time(15, 30), end: time(17, 0))
        let entry = portalPlan.merging([hort]).entries(on: .thursday).last!
        XCTAssertEqual(entry.firstPeriod, 9, "one past the last period the school has")
        XCTAssertEqual(entry.lastPeriod, 9)
        XCTAssertEqual(entry.slotLabel, "15:30–17:00", "a derived period is not shown as one")
    }

    func testActivitiesSortAfterTheLessonsOfTheDay() {
        let ag = SchoolActivity(title: "Schach-AG", weekday: .thursday, start: time(14, 10), end: time(15, 0))
        let names = portalPlan.merging([ag]).entries(on: .thursday).map(\.subject.name)
        XCTAssertEqual(names, ["Mathematik", "Deutsch", "Sport", "Schach-AG"])
    }

    func testActivityOnAnEmptyDayCreatesThatDay() {
        let ag = SchoolActivity(title: "Judo", weekday: .friday, start: time(16, 0), end: time(17, 30))
        let merged = portalPlan.merging([ag])
        XCTAssertEqual(merged.entries(on: .friday).map(\.subject.name), ["Judo"])
        XCTAssertTrue(merged.weekdaysInUse.contains(.friday))
    }

    func testWithoutAPeriodTablePeriodsComeFromSingleLessons() {
        var plan = portalPlan
        plan.periods = []
        let ag = SchoolActivity(title: "Theater", weekday: .thursday, start: time(13, 30), end: time(14, 0))
        let entry = plan.merging([ag]).entries(on: .thursday).last!
        XCTAssertEqual(entry.firstPeriod, 7, "Sport is a single 7th-period lesson, so 13:30 is period 7")
    }

    func testActivitiesAloneMakeANonEmptyPlan() {
        let ag = SchoolActivity(title: "Hort", weekday: .monday, start: time(14, 0), end: time(16, 0))
        let merged = Timetable().merging([ag])
        XCTAssertFalse(merged.isEmpty)
        XCTAssertEqual(merged.entries(on: .monday).first?.firstPeriod, 1)
    }

    func testLessonsStayLessons() {
        let merged = portalPlan.merging([SchoolActivity(title: "x", weekday: .monday, start: time(14, 0), end: time(15, 0))])
        XCTAssertFalse(merged.entries(on: .thursday).contains { $0.isActivity })
        XCTAssertEqual(merged.entries(on: .thursday).first?.slotLabel, "1.–2. Stunde")
    }

    func testActivityColourIsStableForATitle() {
        let a = SchoolActivity(title: "Schach-AG", weekday: .monday, start: time(14, 0), end: time(15, 0))
        let b = SchoolActivity(title: "Schach-AG", weekday: .tuesday, start: time(15, 0), end: time(16, 0))
        XCTAssertEqual(a.colorHex, b.colorHex)
        XCTAssertEqual(a.subject.code, "AG")
    }

    func testActivitiesRoundTripThroughJSON() throws {
        let original = SchoolActivity(title: "DELF", weekday: .thursday, start: time(14, 10), end: time(14, 55),
                                room: "1.03", leader: "Frau Letzgus", note: "Beginn 27.08.")
        let decoded = try JSONDecoder().decode(SchoolActivity.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testTimetablesCachedBeforeActivitiesStillDecode() throws {
        let json = """
        {"entries":[{"id":"x","weekday":1,"firstPeriod":1,"lastPeriod":1,
          "start":{"hour":8,"minute":10},"end":{"hour":8,"minute":55},"rawTitle":"M",
          "subject":{"code":"M","name":"Mathematik","colorHex":"#000000"}}],"periods":[]}
        """
        let plan = try JSONDecoder().decode(Timetable.self, from: Data(json.utf8))
        XCTAssertFalse(plan.entries[0].isActivity)
    }
}
