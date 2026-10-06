import Foundation
import Observation

/// How reminders should currently be presented, considering real meetings and manual Quiet Mode.
public enum QuietReason: Equatable, Sendable {
    case none
    /// A real meeting / protected audio activity was detected.
    case meeting(MeetingState)
    /// The user manually enabled Quiet Mode (presentation only).
    case manual

    /// Bundle identifier associated with a detected meeting, if any.
    public var bundleIdentifier: String? {
        switch self {
        case .none, .manual: return nil
        case .meeting(let s): return s.bundleIdentifier
        }
    }
}

/// The central, UI-independent state machine. Owns all transitions.
///
/// Driven by `tick(now:)` roughly every second from the app's scheduler. Uses
/// timestamp/delta logic (not accumulator counters) so it tolerates drift and suspension.
///
/// IMPORTANT semantics:
/// - A *real detected meeting* suppresses idle-based natural-break resets and
///   auto-complete (someone may sit silently in a call).
/// - *Manual Quiet Mode* affects reminder PRESENTATION ONLY. It never changes
///   active/idle accounting, natural-break detection, or auto-complete.
@MainActor
@Observable
public final class BreakCoordinator {

    // MARK: Dependencies
    private let time: TimeProvider
    private let activity: UserActivityMonitoring
    private let meeting: MeetingDetecting
    private let lifecycle: LifecycleMonitoring
    private let presenter: ReminderPresenting

    // MARK: Settings & stats
    public var settings: AppSettings {
        didSet { if settings != oldValue { clampForSettingsChange() } }
    }
    public private(set) var stats: DailyStats
    /// Called whenever stats change so the app can persist them.
    public var onStatsChange: ((DailyStats) -> Void)?
    /// Called whenever settings change so the app can persist them.
    public var onSettingsChange: ((AppSettings) -> Void)?

    // MARK: Observable UI state
    public private(set) var state: BreakState = .working
    /// Remaining work seconds until due (when working/warning), clamped at 0.
    public private(set) var remainingWork: TimeInterval
    /// Remaining break seconds (when breakInProgress).
    public private(set) var remainingBreak: TimeInterval = 0
    public private(set) var snoozeCount: Int = 0
    /// Current effective quieting reason (meeting or manual).
    public private(set) var quietReason: QuietReason = .none

    // MARK: Internal timekeeping
    /// Timestamp of the last tick, to compute active-work deltas.
    private var lastTickAt: Date?
    /// Accumulated active work seconds in the current cycle.
    private var accumulatedWork: TimeInterval = 0
    /// When the break first became due (for sound escalation + post-due inactivity).
    private var dueSince: Date?
    /// Idle seconds measured at the instant the break became due (baseline for auto-complete).
    private var idleAtDue: TimeInterval = 0
    /// Which sound escalation alerts have already fired for the current due event.
    private var firedSoundIndices: Set<Int> = []
    /// Manual Quiet Mode expiry (nil = off; distantFuture = until turned off).
    private var manualQuietUntil: Date?
    /// Meeting-exit debounce bookkeeping handled by detector; here we track quiet reminders.
    private var quietRemindersShown: Int = 0
    private var lastQuietReminderAt: Date?
    /// Whether we have presented the current aggressive/quiet surface already.
    private var presentedState: BreakState?

    public init(
        settings: AppSettings,
        stats: DailyStats,
        time: TimeProvider,
        activity: UserActivityMonitoring,
        meeting: MeetingDetecting,
        lifecycle: LifecycleMonitoring,
        presenter: ReminderPresenting
    ) {
        self.settings = settings
        self.time = time
        self.activity = activity
        self.meeting = meeting
        self.lifecycle = lifecycle
        self.presenter = presenter
        self.remainingWork = settings.workInterval
        self.stats = stats.rolledOver(to: time.now())
    }

    // MARK: - Public control actions

    /// Begin a fresh 30-minute (configured) work cycle.
    public func startFreshCycle() {
        accumulatedWork = 0
        snoozeCount = 0
        quietRemindersShown = 0
        lastQuietReminderAt = nil
        dueSince = nil
        idleAtDue = 0
        firedSoundIndices.removeAll()
        remainingWork = settings.workInterval
        setState(.working)
        updatePresentation(now: time.now())
    }

    /// User chose to start the break now (from menu or reminder).
    public func startBreak() {
        let until = time.now().addingTimeInterval(settings.breakDuration)
        remainingBreak = settings.breakDuration
        dueSince = nil
        firedSoundIndices.removeAll()
        setState(.breakInProgress(until: until))
        updatePresentation(now: time.now())
    }

    /// Snooze the due break if allowed.
    public func snooze() {
        guard canSnooze else { return }
        snoozeCount += 1
        bumpStats { $0.snoozes += 1 }
        let until = time.now().addingTimeInterval(settings.snoozeDuration)
        dueSince = nil
        firedSoundIndices.removeAll()
        setState(.snoozed(until: until))
        updatePresentation(now: time.now())
    }

    /// Skip this break entirely; start a fresh cycle.
    public func skip() {
        bumpStats { $0.skippedBreaks += 1 }
        startFreshCycle()
    }

    public var canSnooze: Bool {
        state.isBreakOutstanding && snoozeCount < settings.maxSnoozes
    }

    /// Pause StandUp indefinitely.
    public func pause() {
        setState(.paused(until: nil))
        updatePresentation(now: time.now())
    }

    /// Resume from pause into a fresh cycle.
    public func resume() {
        startFreshCycle()
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    // MARK: Manual Quiet Mode

    /// Enable manual Quiet Mode for a duration (nil = until turned off).
    public func enableManualQuiet(for duration: TimeInterval?) {
        if let d = duration {
            manualQuietUntil = time.now().addingTimeInterval(d)
        } else {
            manualQuietUntil = .distantFuture
        }
        updatePresentation(now: time.now())
    }

    public func disableManualQuiet() {
        manualQuietUntil = nil
        updatePresentation(now: time.now())
    }

    public var isManualQuietActive: Bool {
        guard let until = manualQuietUntil else { return false }
        return until > time.now()
    }

    // MARK: - Main tick

    /// Advance the state machine. Called ~1/sec by the scheduler (or by tests).
    public func tick(now: Date) {
        rollStatsIfNeeded(now: now)
        handleSleepIfNeeded(now: now)
        expireManualQuietIfNeeded(now: now)

        defer { lastTickAt = now }

        switch state {
        case .paused:
            return
        case .breakInProgress(let until):
            tickBreakInProgress(now: now, until: until)
        case .snoozed(let until):
            tickSnoozed(now: now, until: until)
        case .working, .warning:
            tickWorking(now: now)
        case .due, .deferredForMeeting:
            tickDue(now: now)
        }
    }

    // MARK: - Tick handlers

    private func tickWorking(now: Date) {
        let idle = activity.idleDuration
        let inRealMeeting = meeting.state.isQuieting && settings.automaticMeetingDetection

        // Natural break: long inactivity resets the cycle — but NOT during a real meeting.
        if idle >= settings.naturalBreakThreshold && !inRealMeeting {
            // User has been away long enough; the next activity starts fresh.
            // We reset immediately so returning shows a full timer.
            if accumulatedWork > 0 || remainingWork < settings.workInterval {
                startFreshCycle()
            }
            return
        }

        // Accumulate active work only when idle is under the pause threshold.
        if let last = lastTickAt {
            let delta = now.timeIntervalSince(last)
            if delta > 0 && idle < settings.idlePauseThreshold {
                accumulatedWork += delta
                bumpStats { $0.activeWorkSeconds += delta }
            }
        }

        remainingWork = max(0, settings.workInterval - accumulatedWork)

        if accumulatedWork >= settings.workInterval {
            becomeDue(now: now)
            return
        }

        // Warning vs working.
        if remainingWork <= settings.warningThreshold {
            setState(.warning)
        } else {
            setState(.working)
        }
        updatePresentation(now: now)
    }

    private func becomeDue(now: Date) {
        dueSince = now
        idleAtDue = activity.idleDuration
        firedSoundIndices.removeAll()
        quietRemindersShown = 0
        lastQuietReminderAt = nil
        remainingWork = 0
        evaluateDueState(now: now)
    }

    private func tickDue(now: Date) {
        // Auto-complete: only counts inactivity AFTER due, and NOT during a real meeting.
        if settings.autoCompleteOnInactivity && !isRealMeetingActive {
            let idle = activity.idleDuration
            // The user must have been continuously idle for the full break duration
            // since the break became due. Idle measured now reflects continuous idle.
            if let due = dueSince,
               now.timeIntervalSince(due) >= settings.breakDuration,
               idle >= settings.breakDuration {
                completeBreak(now: now)
                return
            }
        }
        evaluateDueState(now: now)
    }

    private func tickSnoozed(now: Date, until: Date) {
        if now >= until {
            // Snooze expired → re-arm due.
            dueSince = now
            idleAtDue = activity.idleDuration
            firedSoundIndices.removeAll()
            evaluateDueState(now: now)
        } else {
            updatePresentation(now: now)
        }
    }

    private func tickBreakInProgress(now: Date, until: Date) {
        remainingBreak = max(0, until.timeIntervalSince(now))
        if now >= until {
            completeBreak(now: now)
        } else {
            updatePresentation(now: now)
        }
    }

    /// Decide between aggressive `.due` and quiet `.deferredForMeeting`, considering
    /// real meeting detection and manual Quiet Mode (presentation only).
    private func evaluateDueState(now: Date) {
        let quieting = currentQuietReason(now: now)
        quietReason = quieting
        if quieting == .none {
            setState(.due)
        } else {
            setState(.deferredForMeeting)
        }
        updatePresentation(now: now)
    }

    private func completeBreak(now: Date) {
        bumpStats { $0.completedBreaks += 1 }
        startFreshCycle()
    }

    // MARK: - Quieting

    private var isRealMeetingActive: Bool {
        settings.automaticMeetingDetection && meeting.state.isQuieting
    }

    private func currentQuietReason(now: Date) -> QuietReason {
        if isRealMeetingActive {
            return .meeting(meeting.state)
        }
        if isManualQuietActive {
            return .manual
        }
        return .none
    }

    private func expireManualQuietIfNeeded(now: Date) {
        if let until = manualQuietUntil, until <= now {
            manualQuietUntil = nil
        }
    }

    // MARK: - Presentation

    private func updatePresentation(now: Date) {
        switch state {
        case .working, .warning, .paused, .snoozed:
            presenter.present(.none)
        case .breakInProgress(let until):
            presenter.present(.breakInProgress(until: until))
        case .due:
            presentAggressive(now: now)
        case .deferredForMeeting:
            presentQuiet(now: now)
        }
    }

    private func presentAggressive(now: Date) {
        guard let due = dueSince else {
            presenter.present(.aggressive(soundAlertIndex: nil))
            return
        }
        let elapsed = now.timeIntervalSince(due)
        var alertIndex: Int? = nil
        if settings.soundEnabled {
            for (i, offset) in Constants.Sound.escalationOffsets.enumerated()
            where i < Constants.Sound.maxAlerts {
                if elapsed + 0.001 >= offset && !firedSoundIndices.contains(i) {
                    firedSoundIndices.insert(i)
                    alertIndex = i
                    break
                }
            }
        }
        presenter.present(.aggressive(soundAlertIndex: alertIndex))
    }

    private func presentQuiet(now: Date) {
        // Repeat quiet reminder on cadence, bounded by maxQuietReminders.
        let cadence = Constants.Meeting.quietReminderCadence
        let shouldShow: Bool
        if quietRemindersShown == 0 {
            shouldShow = true
        } else if quietRemindersShown < Constants.Meeting.maxQuietReminders,
                  let last = lastQuietReminderAt,
                  now.timeIntervalSince(last) >= cadence {
            shouldShow = true
        } else {
            shouldShow = false
        }

        if shouldShow && settings.quietMeetingReminders {
            quietRemindersShown += 1
            lastQuietReminderAt = now
            presenter.present(.quietMeeting(bundleIdentifier: quietReason.bundleIdentifier))
        } else {
            // Menu bar still reflects the state; no new surface.
            presenter.present(.none)
        }
    }

    // MARK: - Sleep / lifecycle

    private func handleSleepIfNeeded(now: Date) {
        guard let slept = lifecycle.consumePendingSleepDuration() else { return }
        // Do not count sleep as active work. If asleep long enough, treat as a break.
        if slept >= settings.naturalBreakThreshold {
            startFreshCycle()
        }
        // For short sleeps, simply don't advance work (lastTickAt reset below).
        lastTickAt = nil
    }

    // MARK: - Stats

    private func rollStatsIfNeeded(now: Date) {
        let rolled = stats.rolledOver(to: now)
        if rolled != stats {
            stats = rolled
            onStatsChange?(stats)
        }
    }

    private func bumpStats(_ mutate: (inout DailyStats) -> Void) {
        var s = stats
        mutate(&s)
        stats = s
        onStatsChange?(stats)
    }

    // MARK: - Helpers

    private func setState(_ newState: BreakState) {
        if state != newState { state = newState }
    }

    private func clampForSettingsChange() {
        onSettingsChange?(settings)
        // If currently working, re-derive remaining from the new interval.
        if case .working = state {
            remainingWork = max(0, settings.workInterval - accumulatedWork)
        } else if case .warning = state {
            remainingWork = max(0, settings.workInterval - accumulatedWork)
        }
    }

    // MARK: - Menu bar label

    /// A compact representation the menu-bar label view can render.
    public struct MenuBarLabel: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case working, warning, due, dueInMeeting, breakRunning, paused
        }
        public var kind: Kind
        public var text: String
        public var accessibilityDescription: String
    }

    public func menuBarLabel() -> MenuBarLabel {
        switch state {
        case .working:
            let t = formatMMSS(remainingWork)
            return .init(kind: .working, text: t,
                         accessibilityDescription: "Next break in \(spoken(remainingWork))")
        case .warning:
            let t = formatMMSS(remainingWork)
            return .init(kind: .warning, text: t,
                         accessibilityDescription: "Break soon, \(spoken(remainingWork)) remaining")
        case .snoozed(let until):
            let t = formatMMSS(max(0, until.timeIntervalSince(time.now())))
            return .init(kind: .working, text: t,
                         accessibilityDescription: "Snoozed, \(spoken(max(0, until.timeIntervalSince(time.now())))) remaining")
        case .due:
            return .init(kind: .due, text: "GET UP",
                         accessibilityDescription: "Break due, time to stand up")
        case .deferredForMeeting:
            return .init(kind: .dueInMeeting, text: "Due",
                         accessibilityDescription: "Break due, deferred because you're in a call")
        case .breakInProgress:
            let t = formatMMSS(remainingBreak)
            return .init(kind: .breakRunning, text: t,
                         accessibilityDescription: "Break in progress, \(spoken(remainingBreak)) remaining")
        case .paused:
            return .init(kind: .paused, text: "Paused",
                         accessibilityDescription: "StandUp is paused")
        }
    }

    private func formatMMSS(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        if m > 0 { return "\(m) minute\(m == 1 ? "" : "s") \(r) second\(r == 1 ? "" : "s")" }
        return "\(r) second\(r == 1 ? "" : "s")"
    }
}
