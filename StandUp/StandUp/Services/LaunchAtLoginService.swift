import Foundation
import ServiceManagement
import StandUpCore

/// Wraps `SMAppService.mainApp` for launch-at-login. Reflects the real OS registration
/// status rather than a cached boolean, and surfaces the "requires approval" case.
@MainActor
final class LaunchAtLoginService: ObservableObject {

    enum Status: Equatable {
        case enabled
        case notRegistered
        case requiresApproval
        case unavailable
    }

    @Published private(set) var status: Status = .notRegistered

    init() {
        refresh()
    }

    var isEnabled: Bool { status == .enabled }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            status = .enabled
        case .requiresApproval:
            status = .requiresApproval
        case .notRegistered:
            status = .notRegistered
        case .notFound:
            status = .notRegistered
        @unknown default:
            status = .unavailable
        }
    }

    /// Enable or disable launch at login, handling errors gracefully.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            Log.lifecycle.error("Launch-at-login change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    /// Open the Login Items settings pane so the user can approve if required.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
