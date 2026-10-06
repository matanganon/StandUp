import SwiftUI
import Observation
import StandUpCore

/// Owns the coordinator, concrete system monitors, persistence, and the scheduler loop.
/// This is the single composition root wired into the SwiftUI scenes.
@MainActor
@Observable
final class AppModel {

    let coordinator: BreakCoordinator
    @ObservationIgnored let launchAtLogin = LaunchAtLoginService()

    @ObservationIgnored private let activity: SystemUserActivityMonitor
    @ObservationIgnored private let meetingDetector: MeetingDetecting
    @ObservationIgnored private let coreAudioDetector: CoreAudioMeetingDetector?
    @ObservationIgnored private let lifecycle: WorkspaceLifecycleMonitor
    @ObservationIgnored private let presenter: ReminderPresenter
    @ObservationIgnored private let store: PersistenceStore

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var meetingTask: Task<Void, Never>?

    /// Whether DEBUG fast-testing timings are active (via launch arg / env).
    let isFastTesting: Bool

    init() {
        // Fast-testing hook: --fast-testing launch arg or STANDUP_FAST_TESTING=1 env.
        #if DEBUG
        let fast = ProcessInfo.processInfo.arguments.contains("--fast-testing")
            || ProcessInfo.processInfo.environment["STANDUP_FAST_TESTING"] == "1"
        #else
        let fast = false
        #endif
        self.isFastTesting = fast

        let store = PersistenceStore()
        self.store = store
        // Fast testing overrides persisted settings for this launch only.
        let settings: AppSettings
        #if DEBUG
        settings = fast ? AppSettings.fastTesting : store.loadSettings()
        #else
        settings = store.loadSettings()
        #endif
        let stats = store.loadStats()

        let activity = SystemUserActivityMonitor()
        self.activity = activity

        let lifecycle = WorkspaceLifecycleMonitor()
        self.lifecycle = lifecycle

        let presenter = ReminderPresenter()
        self.presenter = presenter

        // Meeting detector with graceful fallback to no-op.
        let ca = CoreAudioMeetingDetector(fastTesting: fast)
        if ca.isAvailable {
            self.coreAudioDetector = ca
            self.meetingDetector = ca
        } else {
            self.coreAudioDetector = nil
            self.meetingDetector = NoopMeetingDetector()
        }
        let detector = self.meetingDetector

        let coordinator = BreakCoordinator(
            settings: settings,
            stats: stats,
            time: SystemTimeProvider(),
            activity: activity,
            meeting: detector,
            lifecycle: lifecycle,
            presenter: presenter
        )
        self.coordinator = coordinator

        // Persist on changes.
        coordinator.onStatsChange = { store.saveStats($0) }
        coordinator.onSettingsChange = { store.saveSettings($0) }

        // Wire presenter actions back to the coordinator.
        presenter.startBreak = { [weak coordinator] in coordinator?.startBreak() }
        presenter.snooze = { [weak coordinator] in coordinator?.snooze() }
        presenter.skip = { [weak coordinator] in coordinator?.skip() }
        syncPresenterContext()

        start()
    }

    /// Keep presenter display context in sync with current settings/state.
    private func syncPresenterContext() {
        presenter.workMinutes = Int(coordinator.settings.workInterval / 60)
        presenter.canSnooze = coordinator.canSnooze
    }

    func start() {
        // 1-second UI/state tick.
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    guard let self else { return }
                    self.coordinator.tick(now: Date())
                    self.syncPresenterContext()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        // ~2-second meeting sampling (only if detection is available & enabled).
        meetingTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self, self.coordinator.settings.automaticMeetingDetection {
                    self.coreAudioDetector?.sample()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        tickTask?.cancel(); tickTask = nil
        meetingTask?.cancel(); meetingTask = nil
    }

    /// Show the aggressive reminder as a visual preview, without sound or state changes.
    func previewReminder() {
        presenter.showPreview()
    }

    // MARK: - Settings bridge

    var settings: AppSettings {
        get { coordinator.settings }
        set { coordinator.settings = newValue; syncPresenterContext() }
    }

    /// Diagnostic string for the Settings meeting tab.
    var meetingStatusText: String {
        guard coordinator.settings.automaticMeetingDetection else {
            return "Automatic detection is off"
        }
        guard let ca = coreAudioDetector, ca.isAvailable else {
            return "Detection unavailable on this system"
        }
        switch meetingDetector.state {
        case .none:
            return "No call detected"
        case .likelyMeeting(let id):
            return "Call detected — \(friendlyName(id))"
        case .protectedAudioActivity(let id):
            return "Microphone in use — \(friendlyName(id))"
        }
    }

    var isMeetingDetectionAvailable: Bool {
        coreAudioDetector?.isAvailable ?? false
    }

    private func friendlyName(_ bundleID: String?) -> String {
        guard let id = bundleID else { return "an app" }
        let known: [String: String] = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams2": "Microsoft Teams",
            "com.microsoft.teams": "Microsoft Teams",
            "com.tinyspeck.slackmacgap": "Slack",
            "com.apple.FaceTime": "FaceTime",
            "com.hnc.Discord": "Discord",
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Chrome",
            "com.microsoft.edgemac": "Edge",
            "org.mozilla.firefox": "Firefox",
            "company.thebrowser.Browser": "Arc"
        ]
        return known[id] ?? id
    }
}
