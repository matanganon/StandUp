import XCTest
@testable import StandUp
import StandUpCore

/// App-target smoke tests. The exhaustive business-logic suite lives in the
/// StandUpCore package (`swift test`); these verify the app layer wires up.
@MainActor
final class StandUpAppTests: XCTestCase {

    func testMeetingDecisionReducerReachableFromAppTarget() {
        // Sanity: the core module is linked and usable from the app target.
        var reducer = MeetingDecisionReducer()
        let now = Date()
        let state = reducer.update(signals: [], now: now)
        XCTAssertEqual(state, .none)
    }

    func testActivityMonitorReturnsNonNegativeIdle() {
        let monitor = SystemUserActivityMonitor()
        XCTAssertGreaterThanOrEqual(monitor.idleDuration, 0)
    }

    func testCoreAudioDetectorConstructsWithFallback() {
        // Must never crash; availability may be true or false in CI.
        let detector = CoreAudioMeetingDetector()
        _ = detector.isAvailable
        _ = detector.state
    }
}
