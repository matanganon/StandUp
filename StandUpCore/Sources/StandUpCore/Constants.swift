import Foundation

/// Centralized configuration for intervals, thresholds, debounce values, and the
/// bundle-identifier sets used for meeting classification.
///
/// All timing values are expressed in seconds. Production defaults live in
/// `Defaults`; the DEBUG-only fast-testing values live in `FastTesting`.
public enum Constants {

    // MARK: - Production defaults (seconds unless noted)

    public enum Defaults {
        /// Work interval before a break becomes due. Default 30 minutes.
        public static let workInterval: TimeInterval = 30 * 60
        /// Break duration. Default 2 minutes.
        public static let breakDuration: TimeInterval = 2 * 60
        /// Warning threshold before break is due. Default 5 minutes.
        public static let warningThreshold: TimeInterval = 5 * 60
        /// Idle time after which active-work accumulation pauses. Default 60 seconds.
        public static let idlePauseThreshold: TimeInterval = 60
        /// Idle time that counts as a natural break (fresh cycle on return). Default 5 minutes.
        public static let naturalBreakThreshold: TimeInterval = 5 * 60
        /// Snooze duration. Default 5 minutes.
        public static let snoozeDuration: TimeInterval = 5 * 60
        /// Maximum snoozes per break cycle. Default 2.
        public static let maxSnoozes: Int = 2
    }

    // MARK: - DEBUG-only fast testing values

    /// Compressed timings so manual QA does not require waiting 30 minutes.
    /// Enabled only via launch argument / environment (see `AppSettings`).
    /// Never used for production defaults.
    public enum FastTesting {
        public static let workInterval: TimeInterval = 30
        public static let breakDuration: TimeInterval = 10
        public static let warningThreshold: TimeInterval = 5
        public static let idlePauseThreshold: TimeInterval = 10
        public static let naturalBreakThreshold: TimeInterval = 15
        public static let snoozeDuration: TimeInterval = 10
        public static let maxSnoozes: Int = 2
    }

    // MARK: - Meeting detection timing (internal, not user-exposed)

    public enum Meeting {
        /// A qualifying signal must be stable this long before entering meeting mode.
        public static let enterDebounce: TimeInterval = 3
        /// No qualifying signal for this long before exiting meeting mode.
        public static let exitDebounce: TimeInterval = 8
        /// For browsers: once microphone activity has established a meeting, keep it
        /// sticky this long while output continues (handles mic mute during a call).
        public static let browserStickyGrace: TimeInterval = 120
        /// A known communication app with output-only (mic muted) must sustain this long
        /// to be considered a meeting on its own.
        public static let outputOnlySustain: TimeInterval = 5
        /// Cadence of repeated quiet reminders during a long continuous meeting.
        public static let quietReminderCadence: TimeInterval = 15 * 60
        /// Maximum quiet reminders during one continuous meeting.
        public static let maxQuietReminders: Int = 3
    }

    public enum FastTestingMeeting {
        public static let enterDebounce: TimeInterval = 2
        public static let exitDebounce: TimeInterval = 3
        public static let browserStickyGrace: TimeInterval = 15
        public static let outputOnlySustain: TimeInterval = 3
        public static let quietReminderCadence: TimeInterval = 30
        public static let maxQuietReminders: Int = 3
    }

    // MARK: - Reminder sound escalation

    public enum Sound {
        /// Offsets (seconds) from break-due at which an alert sound plays.
        public static let escalationOffsets: [TimeInterval] = [0, 60, 120]
        public static let maxAlerts: Int = 3
    }

    // MARK: - Bundle identifiers

    /// Known native communication applications (calls/meetings).
    public static let communicationAppBundleIDs: Set<String> = [
        "us.zoom.xos",              // Zoom
        "com.microsoft.teams2",     // Microsoft Teams (new)
        "com.microsoft.teams",      // Microsoft Teams (classic)
        "com.tinyspeck.slackmacgap",// Slack
        "com.apple.FaceTime",       // FaceTime
        "com.hnc.Discord",          // Discord
        "com.cisco.webexmeetingsapp", // Webex
        "com.microsoft.SkypeForBusiness", // Skype for Business
        "com.skype.skype",          // Skype
        "com.google.meetings"       // Google Meet standalone (if installed)
    ]

    /// Browsers. Audio output alone from a browser must NOT be treated as a meeting;
    /// browser microphone input is the strong signal.
    public static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]
}
