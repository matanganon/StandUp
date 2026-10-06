import Foundation

/// The result of meeting / call detection.
///
/// The app never records audio; this only reflects audio-process activity metadata.
public enum MeetingState: Equatable, Sendable {
    /// No call or protected audio activity detected.
    case none
    /// A known communication app (or browser with microphone activity) is likely in a call.
    case likelyMeeting(appBundleIdentifier: String?)
    /// An unknown process is actively using microphone input — treat as protected
    /// (quiet) mode even though we cannot confirm it is a meeting.
    case protectedAudioActivity(appBundleIdentifier: String?)

    /// Whether this state should quiet reminders (behaves like a meeting for presentation).
    public var isQuieting: Bool {
        switch self {
        case .none: return false
        case .likelyMeeting, .protectedAudioActivity: return true
        }
    }

    /// Bundle identifier associated with the quieting state, if any.
    public var bundleIdentifier: String? {
        switch self {
        case .none: return nil
        case let .likelyMeeting(id), let .protectedAudioActivity(id): return id
        }
    }
}
