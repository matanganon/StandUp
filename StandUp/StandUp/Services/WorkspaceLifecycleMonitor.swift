import Foundation
import AppKit
import StandUpCore

/// Observes NSWorkspace sleep/wake and session lock notifications.
///
/// Records the timestamp at sleep and reports the slept duration exactly once on wake,
/// so the coordinator can decide whether a long sleep counts as a natural break.
final class WorkspaceLifecycleMonitor: LifecycleMonitoring, @unchecked Sendable {

    private let lock = NSLock()
    private var sleptSince: Date?
    private var pendingSleepDuration: TimeInterval?
    private var _locked = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let dncCenter = DistributedNotificationCenter.default()

        let sleepNames: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification
        ]
        let wakeNames: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        for name in sleepNames {
            observers.append(wsCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.markSleepStart()
            })
        }
        for name in wakeNames {
            observers.append(wsCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.markWake()
            })
        }

        // Session lock/unlock via distributed notifications (documented names).
        observers.append(dncCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.setLocked(true) })
        observers.append(dncCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.setLocked(false) })

        Log.lifecycle.info("WorkspaceLifecycleMonitor initialized")
    }

    deinit {
        for o in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            DistributedNotificationCenter.default().removeObserver(o)
        }
    }

    private func markSleepStart() {
        lock.lock(); defer { lock.unlock() }
        if sleptSince == nil { sleptSince = Date() }
        Log.lifecycle.info("System will sleep")
    }

    private func markWake() {
        lock.lock(); defer { lock.unlock() }
        if let since = sleptSince {
            pendingSleepDuration = Date().timeIntervalSince(since)
            sleptSince = nil
            Log.lifecycle.info("System woke after \(Int(self.pendingSleepDuration ?? 0))s asleep")
        }
    }

    private func setLocked(_ locked: Bool) {
        lock.lock(); defer { lock.unlock() }
        _locked = locked
        Log.lifecycle.info("Session locked = \(locked)")
    }

    func consumePendingSleepDuration() -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        let v = pendingSleepDuration
        pendingSleepDuration = nil
        return v
    }

    var isSessionLocked: Bool {
        lock.lock(); defer { lock.unlock() }
        return _locked
    }
}
