import Foundation
import CoreGraphics
import StandUpCore

/// Reports seconds since the last user input using the Core Graphics idle-time API.
///
/// This never installs an event tap, never records input content, and requires no
/// special permission. It only asks the system how long since any input event.
final class SystemUserActivityMonitor: UserActivityMonitoring, @unchecked Sendable {

    /// `kCGAnyInputEventType` is defined in C as `(CGEventType)(~0)` and is not imported
    /// into Swift as a symbol, so reconstruct it from the raw value.
    private static let anyInputEventType = CGEventType(rawValue: ~UInt32(0)) ?? .null

    var idleDuration: TimeInterval {
        // Reports seconds since the most recent input of any kind (keyboard, mouse,
        // tablet) against the combined session event source.
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEventType
        )
        // Guard against pathological values.
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return seconds
    }
}
