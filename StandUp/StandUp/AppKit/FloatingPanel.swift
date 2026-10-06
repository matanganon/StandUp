import AppKit

/// A non-activating floating `NSPanel` configured for auxiliary presentation across
/// Spaces and full-screen apps, without stealing keyboard focus.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect, nonActivating: Bool) {
        var style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        if !nonActivating {
            style.remove(.nonactivatingPanel)
        }
        super.init(contentRect: contentRect, styleMask: style, backing: .buffered, defer: false)

        isFloatingPanel = true
        level = .floating
        // Visible across Spaces and alongside full-screen apps, without switching Spaces.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        // Keep the panel from becoming key unless the user interacts with a control.
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .utilityWindow
    }

    // Allow the panel to host interactive controls without forcing app activation.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
