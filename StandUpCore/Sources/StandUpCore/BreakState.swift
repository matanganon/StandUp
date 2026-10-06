import Foundation

/// Explicit application state. The `BreakCoordinator` owns all transitions.
public enum BreakState: Equatable, Sendable {
    /// Normal active-work countdown.
    case working
    /// Within the warning threshold of the break becoming due.
    case warning
    /// Break is due and should be presented aggressively (not in a meeting).
    case due
    /// Break is due but a meeting/quiet condition defers aggressive presentation.
    case deferredForMeeting
    /// Snoozed until the given date.
    case snoozed(until: Date)
    /// A break is running until the given date.
    case breakInProgress(until: Date)
    /// Paused by the user. `until` is nil for an indefinite pause.
    case paused(until: Date?)

    /// Whether the break is overdue (due in some form, including meeting-deferred/snoozed).
    public var isBreakOutstanding: Bool {
        switch self {
        case .due, .deferredForMeeting, .snoozed:
            return true
        case .working, .warning, .breakInProgress, .paused:
            return false
        }
    }
}
