import XCTest
@testable import SchulportalMobile

/// The Pro reminder times are stored as minutes from midnight; the label and
/// the defaults are what the Mitteilungen footer prints.
@MainActor
final class SettingsTimeTests: XCTestCase {

    func testDefaultsAreTheEveningTimes() {
        XCTAssertEqual(Settings.defaultDigestMinutes, 18 * 60)
        XCTAssertEqual(Settings.defaultHomeworkReminderMinutes, 17 * 60)
    }

    func testTimeLabelPadsHoursAndMinutes() {
        XCTAssertEqual(Settings.timeLabel(minutes: 18 * 60), "18:00")
        XCTAssertEqual(Settings.timeLabel(minutes: 7 * 60 + 5), "07:05")
        XCTAssertEqual(Settings.timeLabel(minutes: 0), "00:00")
        XCTAssertEqual(Settings.timeLabel(minutes: 23 * 60 + 59), "23:59")
    }

    func testReminderMinutesPersistInTheGivenDefaults() {
        let suite = "SettingsTimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.digestMinutes, Settings.defaultDigestMinutes)
        XCTAssertEqual(settings.homeworkReminderMinutes, Settings.defaultHomeworkReminderMinutes)

        settings.digestMinutes = 20 * 60 + 15
        settings.homeworkReminderMinutes = 16 * 60
        XCTAssertEqual(Settings(defaults: defaults).digestMinutes, 20 * 60 + 15)
        XCTAssertEqual(Settings(defaults: defaults).homeworkReminderMinutes, 16 * 60)
    }
}
