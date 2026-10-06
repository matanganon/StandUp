import XCTest
@testable import StandUpCore

final class MeetingLogicTests: XCTestCase {

    private func config() -> MeetingDecisionReducer.Config {
        MeetingDecisionReducer.Config(
            enterDebounce: 3, exitDebounce: 8, browserStickyGrace: 120, outputOnlySustain: 5
        )
    }

    private func advance(_ reducer: inout MeetingDecisionReducer,
                         signals: [AudioProcessSignal],
                         from start: Date, seconds: Int) -> MeetingState {
        var now = start
        var state = reducer.state
        for _ in 0..<seconds {
            now = now.addingTimeInterval(1)
            state = reducer.update(signals: signals, now: now)
        }
        return state
    }

    // Test 14 — YouTube in Chrome must NOT look like a meeting ------------
    func testYouTubeNotAMeeting() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: "com.standup.app")
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let signals = [AudioProcessSignal(bundleID: "com.google.Chrome",
                                          isRunningInput: false, isRunningOutput: true)]
        let state = advance(&r, signals: signals, from: start, seconds: 30)
        XCTAssertEqual(state, .none)
    }

    // Test 15 — Browser call with mic mute stays active during grace ------
    func testBrowserMicMuteStickyGrace() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: nil)
        var now = Date(timeIntervalSinceReferenceDate: 0)

        // 1. Chrome mic active → meeting after debounce.
        let withMic = [AudioProcessSignal(bundleID: "com.google.Chrome",
                                          isRunningInput: true, isRunningOutput: true)]
        for _ in 0..<5 { now = now.addingTimeInterval(1); _ = r.update(signals: withMic, now: now) }
        guard case .likelyMeeting = r.state else { return XCTFail("expected meeting") }

        // 2. Mic stops, output continues → stays meeting within grace (120s).
        let outOnly = [AudioProcessSignal(bundleID: "com.google.Chrome",
                                          isRunningInput: false, isRunningOutput: true)]
        for _ in 0..<60 { now = now.addingTimeInterval(1); _ = r.update(signals: outOnly, now: now) }
        guard case .likelyMeeting = r.state else { return XCTFail("expected still meeting in grace") }

        // 3. After grace expires AND no mic, output alone → exits.
        for _ in 0..<120 { now = now.addingTimeInterval(1); _ = r.update(signals: outOnly, now: now) }
        XCTAssertEqual(r.state, .none)
    }

    // Test 16 — Unknown microphone application → protected ----------------
    func testUnknownMicProtected() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: nil)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let signals = [AudioProcessSignal(bundleID: "com.example.unknownRecorder",
                                          isRunningInput: true, isRunningOutput: false)]
        let state = advance(&r, signals: signals, from: start, seconds: 5)
        guard case .protectedAudioActivity = state else {
            return XCTFail("expected protected audio activity")
        }
    }

    // Known comm app mic → meeting ---------------------------------------
    func testKnownCommAppMic() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: nil)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let signals = [AudioProcessSignal(bundleID: "us.zoom.xos",
                                          isRunningInput: true, isRunningOutput: true)]
        let state = advance(&r, signals: signals, from: start, seconds: 4)
        guard case .likelyMeeting(let id) = state else { return XCTFail("expected meeting") }
        XCTAssertEqual(id, "us.zoom.xos")
    }

    // Known comm app output-only (mic muted) sustained → meeting ----------
    func testCommAppOutputOnlySustained() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: nil)
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let signals = [AudioProcessSignal(bundleID: "com.microsoft.teams2",
                                          isRunningInput: false, isRunningOutput: true)]
        // Needs outputOnlySustain(5) + enterDebounce(3).
        for _ in 0..<10 { now = now.addingTimeInterval(1); _ = r.update(signals: signals, now: now) }
        guard case .likelyMeeting = r.state else { return XCTFail("expected meeting via output-only") }
    }

    // Own process excluded ------------------------------------------------
    func testOwnProcessExcluded() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: "com.standup.app")
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let signals = [AudioProcessSignal(bundleID: "com.standup.app",
                                          isRunningInput: true, isRunningOutput: true)]
        let state = advance(&r, signals: signals, from: start, seconds: 10)
        XCTAssertEqual(state, .none)
    }

    // Single transient blip must not enter (debounce) ---------------------
    func testTransientBlipDebounced() {
        var r = MeetingDecisionReducer(config: config(), ownBundleID: nil)
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let mic = [AudioProcessSignal(bundleID: "com.tinyspeck.slackmacgap",
                                      isRunningInput: true, isRunningOutput: false)]
        // Only 1 second of signal, then gone.
        now = now.addingTimeInterval(1); _ = r.update(signals: mic, now: now)
        now = now.addingTimeInterval(1); _ = r.update(signals: [], now: now)
        XCTAssertEqual(r.state, .none)
    }
}
