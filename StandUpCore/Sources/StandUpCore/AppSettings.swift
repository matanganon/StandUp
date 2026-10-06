import Foundation

/// User-configurable settings, persisted to `UserDefaults`.
///
/// This is a plain value-semantics model inside the core so it is easy to test.
/// The app layer binds it to `UserDefaults` / `@AppStorage`. Production defaults are
/// used unless `fastTesting` is enabled, in which case compressed timings apply so
/// manual QA does not require waiting 30 minutes.
public struct AppSettings: Equatable, Codable, Sendable {

    // MARK: General
    public var workInterval: TimeInterval
    public var breakDuration: TimeInterval
    public var showSecondsInMenuBar: Bool

    // MARK: Reminders
    public var warningThreshold: TimeInterval
    public var soundEnabled: Bool
    public var snoozeDuration: TimeInterval
    public var maxSnoozes: Int
    public var idlePauseThreshold: TimeInterval
    public var naturalBreakThreshold: TimeInterval
    public var autoCompleteOnInactivity: Bool

    // MARK: Meetings
    public var automaticMeetingDetection: Bool
    public var quietMeetingReminders: Bool
    public var aggressiveReminderAfterMeeting: Bool

    public init(
        workInterval: TimeInterval = Constants.Defaults.workInterval,
        breakDuration: TimeInterval = Constants.Defaults.breakDuration,
        showSecondsInMenuBar: Bool = true,
        warningThreshold: TimeInterval = Constants.Defaults.warningThreshold,
        soundEnabled: Bool = true,
        snoozeDuration: TimeInterval = Constants.Defaults.snoozeDuration,
        maxSnoozes: Int = Constants.Defaults.maxSnoozes,
        idlePauseThreshold: TimeInterval = Constants.Defaults.idlePauseThreshold,
        naturalBreakThreshold: TimeInterval = Constants.Defaults.naturalBreakThreshold,
        autoCompleteOnInactivity: Bool = true,
        automaticMeetingDetection: Bool = true,
        quietMeetingReminders: Bool = true,
        aggressiveReminderAfterMeeting: Bool = true
    ) {
        self.workInterval = workInterval
        self.breakDuration = breakDuration
        self.showSecondsInMenuBar = showSecondsInMenuBar
        self.warningThreshold = warningThreshold
        self.soundEnabled = soundEnabled
        self.snoozeDuration = snoozeDuration
        self.maxSnoozes = maxSnoozes
        self.idlePauseThreshold = idlePauseThreshold
        self.naturalBreakThreshold = naturalBreakThreshold
        self.autoCompleteOnInactivity = autoCompleteOnInactivity
        self.automaticMeetingDetection = automaticMeetingDetection
        self.quietMeetingReminders = quietMeetingReminders
        self.aggressiveReminderAfterMeeting = aggressiveReminderAfterMeeting
    }

    /// Production defaults.
    public static let standard = AppSettings()

    /// DEBUG-only compressed timings for fast manual QA. Not a production default.
    public static let fastTesting = AppSettings(
        workInterval: Constants.FastTesting.workInterval,
        breakDuration: Constants.FastTesting.breakDuration,
        showSecondsInMenuBar: true,
        warningThreshold: Constants.FastTesting.warningThreshold,
        soundEnabled: true,
        snoozeDuration: Constants.FastTesting.snoozeDuration,
        maxSnoozes: Constants.FastTesting.maxSnoozes,
        idlePauseThreshold: Constants.FastTesting.idlePauseThreshold,
        naturalBreakThreshold: Constants.FastTesting.naturalBreakThreshold,
        autoCompleteOnInactivity: true,
        automaticMeetingDetection: true,
        quietMeetingReminders: true,
        aggressiveReminderAfterMeeting: true
    )
}
