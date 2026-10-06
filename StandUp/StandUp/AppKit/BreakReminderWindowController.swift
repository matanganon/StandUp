import AppKit
import SwiftUI

/// Presents the aggressive break reminder as a full-screen overlay on the active display.
///
/// The panel covers the entire screen (including under the menu bar on the current
/// Space) with a dark translucent backdrop. It captures mouse clicks so the user
/// cannot interact with apps underneath it — a *soft blocker*, not a locked screen.
///
/// Keyboard focus is NOT stolen: the panel appears non-activating, so keystrokes
/// continue to the frontmost app until the user intentionally clicks the overlay.
/// Cmd+Tab, Force Quit, and all system shortcuts remain functional because these
/// are handled at the window-server level and a normal floating panel does not
/// intercept them.
@MainActor
final class BreakReminderWindowController {

    private var panel: FloatingPanel?
    private var pulse = false

    struct Actions {
        var startBreak: () -> Void
        var snooze: () -> Void
        var skip: () -> Void
    }

    private var actions: Actions?
    private var workMinutes: Int = 30
    private var canSnooze: Bool = true

    /// Show (or update) the full-screen overlay on the active display.
    func show(workMinutes: Int, canSnooze: Bool, actions: Actions) {
        self.actions = actions
        self.workMinutes = workMinutes
        self.canSnooze = canSnooze

        let screenFrame = ScreenPlacement.activeScreenFrame()

        if panel == nil {
            let p = FloatingPanel(contentRect: screenFrame, nonActivating: true)
            // The panel should NOT let mouse events pass through — it is a soft blocker.
            p.ignoresMouseEvents = false
            // Shadow off for a full-screen overlay.
            p.hasShadow = false
            p.contentView = NSHostingView(rootView: makeRoot())
            self.panel = p
            p.orderFrontRegardless()
        } else {
            updateContent()
            if let p = panel {
                p.setFrame(screenFrame, display: true)
                p.orderFrontRegardless()
            }
        }
    }

    /// Trigger a brief visual pulse (used on sound escalation).
    func pulseOnce() {
        pulse = true
        updateContent()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.pulse = false
            self?.updateContent()
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    private func updateContent() {
        guard let p = panel else { return }
        (p.contentView as? NSHostingView<BreakReminderView>)?.rootView = makeRoot()
    }

    private func makeRoot() -> BreakReminderView {
        BreakReminderView(
            workMinutes: workMinutes,
            canSnooze: canSnooze,
            onStartBreak: { [weak self] in self?.actions?.startBreak() },
            onSnooze: { [weak self] in self?.actions?.snooze() },
            onSkip: { [weak self] in self?.actions?.skip() },
            pulse: pulse
        )
    }
}
