import XCTest
@testable import StandUpCore

/// Drives the coordinator with simulated time. Each `run` call advances the mock clock
/// in 1-second steps and ticks the coordinator, mirroring the real scheduler.
@MainActor
final class BreakCoordinatorTests: XCTestCase {

    // Helpers -------------------------------------------------------------

    struct Rig {
        let time: MockTimeProvider
        let activity: MockActivityMonitor
        let meeting: MockMeetingDetector
        let lifecycle: MockLifecycleMonitor
        let presenter: MockReminderPresenter
        let coordinator: BreakCoordinator
    }

    func makeRig(_ settings: AppSettings = .standard) -> Rig {
        let time = MockTimeProvider(start: Date(timeIntervalSinceReferenceDate: 1_000_000))
        let activity = MockActivityMonitor(idleDuration: 0)
        let meeting = MockMeetingDetector(state: .none, isAvailable: true)
        let lifecycle = MockLifecycleMonitor()
        let presenter = MockReminderPresenter()
        let coord = BreakCoordinator(
            settings: settings,
            stats: DailyStats(day: time.now()),
            time: time, activity: activity, meeting: meeting,
            lifecycle: lifecycle, presenter: presenter
        )
        // Prime lastTickAt.
        coord.tick(now: time.now())
        return Rig(time: time, activity: activity, meeting: meeting,
                   lifecycle: lifecycle, presenter: presenter, coordinator: coord)
    }

    /// Advance simulated time `seconds` in 1s steps, ticking each step.
    func run(_ rig: Rig, seconds: Int) {
        for _ in 0..<seconds {
            rig.time.advance(by: 1)
            rig.coordinator.tick(now: rig.time.now())
        }
    }

    // Test 1 — Normal work cycle -----------------------------------------
    func testNormalWorkCycleBecomesDue() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .due)
    }

    // Test 2 — Brief idle period: only active time counts -----------------
    func testBriefIdleOnlyActiveTimeCounts() {
        let rig = makeRig()
        // 10 minutes active
        rig.activity.idleDuration = 0
        run(rig, seconds: 10 * 60)
        // 2 minutes idle beyond the pause threshold (idle grows).
        rig.activity.idleDuration = 120
        run(rig, seconds: 120)
        // Idle period must not have advanced work: still working, >15m remaining.
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertGreaterThan(rig.coordinator.remainingWork, 19 * 60)
        // 20 more active minutes → due.
        rig.activity.idleDuration = 0
        run(rig, seconds: 20 * 60)
        XCTAssertEqual(rig.coordinator.state, .due)
    }

    // Test 3 — Natural break resets the cycle ----------------------------
    func testNaturalBreakResetsCycle() {
        let rig = makeRig()
        run(rig, seconds: 15 * 60) // 15 min work
        XCTAssertLessThan(rig.coordinator.remainingWork, 16 * 60)
        // Away 6 minutes (idle beyond natural break threshold).
        rig.activity.idleDuration = 6 * 60
        run(rig, seconds: 6 * 60)
        // Returns → fresh cycle.
        rig.activity.idleDuration = 0
        run(rig, seconds: 2)
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertGreaterThan(rig.coordinator.remainingWork, 29 * 60)
    }

    // Test 4 — Meeting does not count as natural break -------------------
    func testMeetingPreventsNaturalBreakReset() {
        let rig = makeRig()
        run(rig, seconds: 10 * 60) // 10 min work
        let before = rig.coordinator.remainingWork
        // Meeting active, keyboard idle 15 minutes.
        rig.meeting.state = .likelyMeeting(appBundleIdentifier: "us.zoom.xos")
        rig.activity.idleDuration = 15 * 60
        run(rig, seconds: 15 * 60)
        // Must NOT reset to full cycle.
        XCTAssertLessThanOrEqual(rig.coordinator.remainingWork, before + 1)
        XCTAssertLessThan(rig.coordinator.remainingWork, 25 * 60)
    }

    // Test 5 — Break due during meeting → deferred ------------------------
    func testBreakDueDuringMeetingDefers() {
        let rig = makeRig()
        rig.meeting.state = .likelyMeeting(appBundleIdentifier: "com.microsoft.teams2")
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        // No aggressive presentation.
        XCTAssertFalse(rig.presenter.presentations.contains {
            if case .aggressive = $0 { return true }; return false
        })
    }

    // Test 6 — Meeting ends → aggressive, without restarting cycle --------
    func testMeetingEndsTriggersAggressive() {
        let rig = makeRig()
        rig.meeting.state = .likelyMeeting(appBundleIdentifier: "com.microsoft.teams2")
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        // Meeting ends (detector already applies exit debounce; here it's resolved).
        rig.meeting.state = .none
        run(rig, seconds: 2)
        XCTAssertEqual(rig.coordinator.state, .due)
    }

    // Test 7 — Call begins while aggressive reminder visible --------------
    func testMeetingBeginsWhileReminderVisibleDowngrades() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .due)
        rig.presenter.reset()
        // Call begins.
        rig.meeting.state = .likelyMeeting(appBundleIdentifier: "us.zoom.xos")
        run(rig, seconds: 2)
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        // No new aggressive sound after downgrade.
        XCTAssertFalse(rig.presenter.presentations.contains {
            if case .aggressive(let idx) = $0 { return idx != nil }; return false
        })
    }

    // Test 8 — Snooze ----------------------------------------------------
    func testSnoozeSuppressesThenReturns() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .due)
        rig.coordinator.snooze()
        guard case .snoozed = rig.coordinator.state else {
            return XCTFail("expected snoozed")
        }
        // Before 5 minutes: still snoozed.
        run(rig, seconds: 4 * 60)
        guard case .snoozed = rig.coordinator.state else {
            return XCTFail("expected still snoozed")
        }
        // After expiry: due again.
        run(rig, seconds: 61)
        XCTAssertEqual(rig.coordinator.state, .due)
    }

    // Test 9 — Snooze limit ----------------------------------------------
    func testSnoozeLimit() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertTrue(rig.coordinator.canSnooze)
        rig.coordinator.snooze()
        run(rig, seconds: Int(Constants.Defaults.snoozeDuration) + 2)
        XCTAssertTrue(rig.coordinator.canSnooze)
        rig.coordinator.snooze()
        run(rig, seconds: Int(Constants.Defaults.snoozeDuration) + 2)
        // Two snoozes used (max 2) → no longer allowed.
        XCTAssertFalse(rig.coordinator.canSnooze)
    }

    // Test 10 — Break timer completes ------------------------------------
    func testBreakTimerCompletes() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        rig.coordinator.startBreak()
        guard case .breakInProgress = rig.coordinator.state else {
            return XCTFail("expected breakInProgress")
        }
        run(rig, seconds: Int(Constants.Defaults.breakDuration) + 2)
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertEqual(rig.coordinator.stats.completedBreaks, 1)
        XCTAssertGreaterThan(rig.coordinator.remainingWork, 29 * 60)
    }

    // Test 11 — Auto completion ------------------------------------------
    func testAutoCompletionAfterInactivity() {
        let rig = makeRig()
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .due)
        // No input for the full break duration after due.
        rig.activity.idleDuration = Constants.Defaults.breakDuration + 5
        run(rig, seconds: Int(Constants.Defaults.breakDuration) + 2)
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertEqual(rig.coordinator.stats.completedBreaks, 1)
    }

    // Test 12 — Auto completion must NOT trigger during meeting ----------
    func testAutoCompletionSuppressedDuringMeeting() {
        let rig = makeRig()
        rig.meeting.state = .likelyMeeting(appBundleIdentifier: "com.microsoft.teams2")
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        rig.activity.idleDuration = 5 * 60
        run(rig, seconds: 5 * 60)
        // Still overdue, not auto-completed.
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        XCTAssertEqual(rig.coordinator.stats.completedBreaks, 0)
    }

    // Test 13 — Sleep longer than natural break threshold → fresh cycle ---
    func testLongSleepResetsCycle() {
        let rig = makeRig()
        run(rig, seconds: 20 * 60) // some work done
        XCTAssertLessThan(rig.coordinator.remainingWork, 11 * 60)
        rig.lifecycle.injectSleep(20 * 60) // slept 20 min
        rig.time.advance(by: 20 * 60)
        rig.coordinator.tick(now: rig.time.now())
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertGreaterThan(rig.coordinator.remainingWork, 29 * 60)
    }

    // Manual Quiet Mode must NOT affect auto-complete / idle accounting ---
    func testManualQuietDoesNotSuppressAutoComplete() {
        let rig = makeRig()
        rig.coordinator.enableManualQuiet(for: nil) // until off
        run(rig, seconds: Int(Constants.Defaults.workInterval))
        // Manual quiet → deferred presentation, but still outstanding.
        XCTAssertEqual(rig.coordinator.state, .deferredForMeeting)
        // Auto-complete still applies under manual quiet (presentation-only semantics).
        rig.activity.idleDuration = Constants.Defaults.breakDuration + 5
        run(rig, seconds: Int(Constants.Defaults.breakDuration) + 2)
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertEqual(rig.coordinator.stats.completedBreaks, 1)
    }

    func testManualQuietDoesNotPreventNaturalBreak() {
        let rig = makeRig()
        rig.coordinator.enableManualQuiet(for: nil)
        run(rig, seconds: 10 * 60)
        // Idle beyond natural threshold with only manual quiet (no real meeting) → reset.
        rig.activity.idleDuration = 6 * 60
        run(rig, seconds: 6 * 60)
        rig.activity.idleDuration = 0
        run(rig, seconds: 2)
        XCTAssertEqual(rig.coordinator.state, .working)
        XCTAssertGreaterThan(rig.coordinator.remainingWork, 29 * 60)
    }
}
