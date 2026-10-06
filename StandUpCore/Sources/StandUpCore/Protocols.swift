import Foundation

/// Reports seconds since the last user input (keyboard/mouse/tablet). The concrete
/// implementation uses Core Graphics idle time. It must never record input content.
public protocol UserActivityMonitoring: AnyObject, Sendable {
    /// Seconds since the last input event. 0 means input just occurred.
    var idleDuration: TimeInterval { get }
}

/// Reports current meeting / audio-activity state. The concrete implementation uses
/// Core Audio per-process metadata; it never captures audio.
public protocol MeetingDetecting: AnyObject, Sendable {
    var state: MeetingState { get }
    /// Whether automatic detection is actually available/active on this system.
    var isAvailable: Bool { get }
}

/// Reports relevant lifecycle facts the coordinator needs: sleep spans and session lock.
public protocol LifecycleMonitoring: AnyObject, Sendable {
    /// If the machine recently woke, returns the sleep duration (seconds) exactly once,
    /// then nil. Allows the coordinator to decide on a fresh cycle after a long sleep.
    func consumePendingSleepDuration() -> TimeInterval?
    /// True while the login session is locked / inactive (do not present aggressive UI).
    var isSessionLocked: Bool { get }
}

/// The style of reminder the coordinator wants presented.
public enum ReminderPresentation: Equatable, Sendable {
    case none
    /// Aggressive floating reminder. `soundAlertIndex` indicates which escalation
    /// alert should fire (0,1,2) or nil for no new sound this request.
    case aggressive(soundAlertIndex: Int?)
    /// Quiet meeting reminder (small, no sound, auto-dismiss).
    case quietMeeting(bundleIdentifier: String?)
    /// A break is in progress (countdown surface).
    case breakInProgress(until: Date)
}

/// Abstracts the UI presentation layer so the coordinator is testable without AppKit.
public protocol ReminderPresenting: AnyObject, Sendable {
    func present(_ presentation: ReminderPresentation)
}
