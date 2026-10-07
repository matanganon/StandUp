import AppKit

/// Chooses the screen the user is most likely working on and computes placement rects.
enum ScreenPlacement {

    /// Preferred screen: contains the mouse → main → first.
    static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let s = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return s
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Full frame of the active screen (for the full-screen overlay).
    /// Uses the screen's `.frame` (not `.visibleFrame`) to cover the entire display
    /// including the menu bar area on the current Space.
    static func activeScreenFrame() -> NSRect {
        guard let screen = activeScreen() else {
            return NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
        return screen.frame
    }

    /// Visible frame leaves the menu bar available, which lets a preview be
    /// toggled off from the menu-bar popover without weakening real reminders.
    static func activeScreenVisibleFrame() -> NSRect {
        activeScreen()?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 860)
    }

    /// Top-center placement, ~24pt below the visible top of the active screen.
    static func topCenterRect(size: NSSize, topInset: CGFloat = 24) -> NSRect {
        guard let screen = activeScreen() else {
            return NSRect(origin: .zero, size: size)
        }
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - topInset
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Upper-right placement for the quiet meeting reminder.
    static func upperRightRect(size: NSSize, inset: CGFloat = 16) -> NSRect {
        guard let screen = activeScreen() else {
            return NSRect(origin: .zero, size: size)
        }
        let visible = screen.visibleFrame
        let x = visible.maxX - size.width - inset
        let y = visible.maxY - size.height - inset
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
