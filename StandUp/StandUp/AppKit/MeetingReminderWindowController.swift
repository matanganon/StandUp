import AppKit
import SwiftUI

/// Presents the small, quiet meeting reminder in the upper-right corner. No sound,
/// no focus steal, auto-dismisses after a few seconds.
@MainActor
final class MeetingReminderWindowController {

    private var panel: FloatingPanel?
    private var dismissWork: DispatchWorkItem?

    func show(autoDismissAfter seconds: TimeInterval = 5) {
        if panel == nil {
            let rect = ScreenPlacement.upperRightRect(size: NSSize(width: 320, height: 90))
            let p = FloatingPanel(contentRect: rect, nonActivating: true)
            p.contentView = NSHostingView(rootView: MeetingReminderView())
            self.panel = p
        }
        if let p = panel {
            p.setFrame(ScreenPlacement.upperRightRect(size: NSSize(width: 320, height: 90)), display: true)
            p.orderFrontRegardless()
        }
        scheduleDismiss(after: seconds)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func close() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool { panel?.isVisible ?? false }
}
