import AppKit
import StandUpCore

/// Bridges the coordinator's `ReminderPresenting` protocol to the AppKit panels and
/// system sound. Lives on the main actor since it touches UI.
@MainActor
final class ReminderPresenter: ReminderPresenting {

    private let breakController = BreakReminderWindowController()
    private let meetingController = MeetingReminderWindowController()

    /// Actions the aggressive panel forwards to the coordinator; wired by the app.
    var startBreak: () -> Void = {}
    var snooze: () -> Void = {}
    var skip: () -> Void = {}

    /// Current work interval (minutes) and snooze availability, kept up to date by the app.
    var workMinutes: Int = 30
    var canSnooze: Bool = true

    nonisolated func present(_ presentation: ReminderPresentation) {
        // The protocol is nonisolated; hop to the main actor for UI work.
        Task { @MainActor in self.apply(presentation) }
    }

    private func apply(_ presentation: ReminderPresentation) {
        switch presentation {
        case .none:
            breakController.close()
            // Quiet meeting panel auto-dismisses; don't force-close here so it can linger.
        case .breakInProgress:
            breakController.close()
            meetingController.close()
        case .quietMeeting:
            breakController.close()
            meetingController.show()
        case .aggressive(let soundIndex):
            meetingController.close()
            breakController.show(
                workMinutes: workMinutes,
                canSnooze: canSnooze,
                actions: .init(
                    startBreak: { [weak self] in self?.startBreak() },
                    snooze: { [weak self] in self?.snooze() },
                    skip: { [weak self] in self?.skip() }
                )
            )
            if let idx = soundIndex {
                NSSound.beep()
                if idx > 0 { breakController.pulseOnce() }
                Log.reminder.info("Aggressive reminder alert #\(idx)")
            }
        }
    }

    func closeAll() {
        breakController.close()
        meetingController.close()
    }

    /// Show the aggressive reminder as a preview (no sound, no state change).
    /// The panel's actions dismiss the preview instead of affecting the coordinator.
    func showPreview() {
        meetingController.close()
        breakController.show(
            workMinutes: workMinutes,
            canSnooze: canSnooze,
            actions: .init(
                startBreak: { [weak self] in self?.breakController.close() },
                snooze: { [weak self] in self?.breakController.close() },
                skip: { [weak self] in self?.breakController.close() }
            )
        )
    }
}
