import Foundation

/// Abstracts "now" so the state machine can be driven with simulated time in tests.
///
/// Production uses `SystemTimeProvider`; tests use `MockTimeProvider` to advance
/// time deterministically without waiting.
public protocol TimeProvider: Sendable {
    func now() -> Date
}

/// Real wall-clock time source.
public struct SystemTimeProvider: TimeProvider {
    public init() {}
    public func now() -> Date { Date() }
}

/// Controllable time source for tests. Thread-safe via an internal lock.
public final class MockTimeProvider: TimeProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(start: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.current = start
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    /// Advance simulated time by the given number of seconds.
    public func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }

    /// Set simulated time to an absolute instant.
    public func set(to date: Date) {
        lock.lock(); defer { lock.unlock() }
        current = date
    }
}
