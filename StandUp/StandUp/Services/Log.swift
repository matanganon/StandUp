import OSLog

/// Centralized OSLog categories. Never log sensitive data (URLs, window titles,
/// typed text, audio). Logging a meeting bundle identifier is acceptable.
enum Log {
    private static let subsystem = "com.standup.app"
    static let timer = Logger(subsystem: subsystem, category: "timer")
    static let meeting = Logger(subsystem: subsystem, category: "meeting")
    static let activity = Logger(subsystem: subsystem, category: "activity")
    static let reminder = Logger(subsystem: subsystem, category: "reminder")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
