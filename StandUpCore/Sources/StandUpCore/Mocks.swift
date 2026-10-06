import Foundation

/// Test double for user activity. Set `idleDuration` directly.
public final class MockActivityMonitor: UserActivityMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _idle: TimeInterval = 0
    public init(idleDuration: TimeInterval = 0) { self._idle = idleDuration }
    public var idleDuration: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return _idle }
        set { lock.lock(); defer { lock.unlock() }; _idle = newValue }
    }
}

/// Test double for meeting detection. Set `state` and `isAvailable` directly.
public final class MockMeetingDetector: MeetingDetecting, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: MeetingState
    private var _available: Bool
    public init(state: MeetingState = .none, isAvailable: Bool = true) {
        self._state = state
        self._available = isAvailable
    }
    public var state: MeetingState {
        get { lock.lock(); defer { lock.unlock() }; return _state }
        set { lock.lock(); defer { lock.unlock() }; _state = newValue }
    }
    public var isAvailable: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _available }
        set { lock.lock(); defer { lock.unlock() }; _available = newValue }
    }
}

/// Test double for lifecycle events.
public final class MockLifecycleMonitor: LifecycleMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _pendingSleep: TimeInterval?
    private var _locked: Bool
    public init(isSessionLocked: Bool = false) { self._locked = isSessionLocked }

    public func consumePendingSleepDuration() -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        let v = _pendingSleep
        _pendingSleep = nil
        return v
    }
    /// Simulate a wake after sleeping `seconds`.
    public func injectSleep(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _pendingSleep = seconds
    }
    public var isSessionLocked: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _locked }
        set { lock.lock(); defer { lock.unlock() }; _locked = newValue }
    }
}

/// Records presentation requests for assertions.
public final class MockReminderPresenter: ReminderPresenting, @unchecked Sendable {
    private let lock = NSLock()
    private var _presentations: [ReminderPresentation] = []
    public init() {}
    public func present(_ presentation: ReminderPresentation) {
        lock.lock(); defer { lock.unlock() }
        _presentations.append(presentation)
    }
    public var presentations: [ReminderPresentation] {
        lock.lock(); defer { lock.unlock() }
        return _presentations
    }
    public var last: ReminderPresentation? {
        lock.lock(); defer { lock.unlock() }
        return _presentations.last
    }
    public func reset() {
        lock.lock(); defer { lock.unlock() }
        _presentations.removeAll()
    }
}
