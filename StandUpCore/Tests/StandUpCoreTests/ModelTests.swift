import XCTest
@testable import StandUpCore

final class ModelTests: XCTestCase {

    func testSettingsDefaults() {
        let s = AppSettings.standard
        XCTAssertEqual(s.workInterval, 30 * 60)
        XCTAssertEqual(s.breakDuration, 2 * 60)
        XCTAssertEqual(s.warningThreshold, 5 * 60)
        XCTAssertEqual(s.idlePauseThreshold, 60)
        XCTAssertEqual(s.naturalBreakThreshold, 5 * 60)
        XCTAssertEqual(s.snoozeDuration, 5 * 60)
        XCTAssertEqual(s.maxSnoozes, 2)
        XCTAssertTrue(s.soundEnabled)
        XCTAssertTrue(s.autoCompleteOnInactivity)
        XCTAssertTrue(s.automaticMeetingDetection)
    }

    func testSettingsCodableRoundTrip() throws {
        var s = AppSettings.standard
        s.workInterval = 45 * 60
        s.soundEnabled = false
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(s, decoded)
    }

    func testFastTestingTimings() {
        let s = AppSettings.fastTesting
        XCTAssertEqual(s.workInterval, 30)
        XCTAssertEqual(s.breakDuration, 10)
        XCTAssertEqual(s.warningThreshold, 5)
        // Production defaults untouched.
        XCTAssertEqual(AppSettings.standard.workInterval, 30 * 60)
    }

    func testDailyStatsRollover() {
        let cal = Calendar.current
        let day1 = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        var stats = DailyStats(completedBreaks: 3, snoozes: 1, skippedBreaks: 2, day: day1)
        // Same day: unchanged.
        let same = stats.rolledOver(to: day1.addingTimeInterval(3600))
        XCTAssertEqual(same.completedBreaks, 3)
        // Next day: reset.
        let next = day1.addingTimeInterval(26 * 3600)
        stats = stats.rolledOver(to: next)
        XCTAssertEqual(stats.completedBreaks, 0)
        XCTAssertEqual(stats.snoozes, 0)
        XCTAssertEqual(stats.skippedBreaks, 0)
    }

    func testBreakStateEquatable() {
        let d = Date(timeIntervalSinceReferenceDate: 100)
        XCTAssertEqual(BreakState.snoozed(until: d), BreakState.snoozed(until: d))
        XCTAssertNotEqual(BreakState.working, BreakState.warning)
        XCTAssertTrue(BreakState.due.isBreakOutstanding)
        XCTAssertTrue(BreakState.deferredForMeeting.isBreakOutstanding)
        XCTAssertFalse(BreakState.working.isBreakOutstanding)
    }

    func testMeetingStateQuieting() {
        XCTAssertFalse(MeetingState.none.isQuieting)
        XCTAssertTrue(MeetingState.likelyMeeting(appBundleIdentifier: "x").isQuieting)
        XCTAssertTrue(MeetingState.protectedAudioActivity(appBundleIdentifier: nil).isQuieting)
    }
}
