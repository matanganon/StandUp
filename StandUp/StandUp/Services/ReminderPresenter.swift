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
    var breakMinutes: Int = 2
    var snoozeMinutes: Int = 5
    var canSnooze: Bool = true
    private var isPreviewActive = false

    nonisolated func present(_ presentation: ReminderPresentation) {
        // The protocol is nonisolated; hop to the main actor for UI work.
        Task { @MainActor in self.apply(presentation) }
    }

    private func apply(_ presentation: ReminderPresentation) {
        // The coordinator keeps ticking while preview is open. Ignore those normal
        // presentation updates so `.none` cannot dismiss the preview a second later.
        guard !isPreviewActive else { return }

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
                breakMinutes: breakMinutes,
                snoozeMinutes: snoozeMinutes,
                canSnooze: canSnooze,
                isPreview: false,
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
        isPreviewActive = false
        breakController.close()
        meetingController.close()
    }

    /// Show a sticky aggressive reminder preview (no sound or state change).
    /// Calling it again toggles the preview off.
    func showPreview() {
        if isPreviewActive {
            finishPreview()
            return
        }

        isPreviewActive = true
        meetingController.close()
        breakController.show(
            workMinutes: workMinutes,
            breakMinutes: breakMinutes,
            snoozeMinutes: snoozeMinutes,
            canSnooze: canSnooze,
            isPreview: true,
            actions: .init(
                startBreak: { [weak self] in self?.finishPreview() },
                snooze: {},
                skip: { [weak self] in self?.finishPreview() }
            )
        )
    }

    private func finishPreview() {
        isPreviewActive = false
        breakController.close()
    }
}
