import Foundation
import CoreAudio
import AppKit
import StandUpCore

/// Detects meetings/calls by inspecting per-process audio activity metadata via Core Audio.
///
/// This NEVER records audio and NEVER creates a process tap. It only reads the system's
/// list of audio processes and their running-input / running-output / bundle-id metadata,
/// then feeds raw signals into the pure `MeetingDecisionReducer`.
///
/// The modern high-level Swift API (`AudioHardwareSystem.processes`) is not present in
/// this SDK, so we use the documented low-level per-process AudioObject properties
/// (`kAudioHardwarePropertyProcessObjectList`, `kAudioProcessProperty*`), introduced in
/// macOS 14.2. If these are unavailable or fail, we fall back to a no-op (never a meeting)
/// so the app keeps working with normal reminders + manual Quiet Mode.
final class CoreAudioMeetingDetector: MeetingDetecting, @unchecked Sendable {

    private let lock = NSLock()
    private var reducer: MeetingDecisionReducer
    private var _state: MeetingState = .none
    private let _available: Bool

    init(fastTesting: Bool = false) {
        let config: MeetingDecisionReducer.Config
        if fastTesting {
            config = MeetingDecisionReducer.Config(
                enterDebounce: Constants.FastTestingMeeting.enterDebounce,
                exitDebounce: Constants.FastTestingMeeting.exitDebounce,
                browserStickyGrace: Constants.FastTestingMeeting.browserStickyGrace,
                outputOnlySustain: Constants.FastTestingMeeting.outputOnlySustain
            )
        } else {
            config = MeetingDecisionReducer.Config()
        }
        let ownID = Bundle.main.bundleIdentifier
        self.reducer = MeetingDecisionReducer(config: config, ownBundleID: ownID)
        // Availability: the process object list property exists on macOS 14.2+.
        self._available = CoreAudioMeetingDetector.processListAvailable()
        if _available {
            Log.meeting.info("Core Audio process inspection available")
        } else {
            Log.meeting.info("Core Audio process inspection unavailable; using fallback (manual Quiet Mode only)")
        }
    }

    var isAvailable: Bool { _available }

    var state: MeetingState {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    /// Sample the system now and update the debounced meeting state. Called ~every 2s.
    func sample() {
        guard _available else { return }
        let now = Date()
        let signals = readProcessSignals()
        lock.lock()
        let newState = reducer.update(signals: signals, now: now)
        let changed = newState != _state
        _state = newState
        lock.unlock()
        if changed {
            switch newState {
            case .none:
                Log.meeting.info("Meeting state cleared")
            case .likelyMeeting(let id):
                Log.meeting.info("Meeting detected for bundle: \(id ?? "unknown", privacy: .public)")
            case .protectedAudioActivity(let id):
                Log.meeting.info("Protected audio activity for bundle: \(id ?? "unknown", privacy: .public)")
            }
        }
    }

    // MARK: - Core Audio low-level reads

    private static func processListAvailable() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(AudioObjectID(kAudioObjectSystemObject), &address)
    }

    private func readProcessSignals() -> [AudioProcessSignal] {
        let processIDs = processObjectIDs()
        guard !processIDs.isEmpty else { return [] }
        var result: [AudioProcessSignal] = []
        result.reserveCapacity(processIDs.count)
        for pid in processIDs {
            let runningInput = boolProperty(pid, kAudioProcessPropertyIsRunningInput)
            let runningOutput = boolProperty(pid, kAudioProcessPropertyIsRunningOutput)
            // Skip entirely-silent processes to keep the signal set small.
            guard runningInput || runningOutput else { continue }
            let bundleID = stringProperty(pid, kAudioProcessPropertyBundleID)
            result.append(AudioProcessSignal(
                bundleID: bundleID,
                isRunningInput: runningInput,
                isRunningOutput: runningOutput
            ))
        }
        return result
    }

    private func processObjectIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard sizeStatus == noErr, dataSize > 0 else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        )
        guard status == noErr else { return [] }
        return ids
    }

    private func boolProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(object, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        guard status == noErr else { return false }
        return value != 0
    }

    private func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cfStr: CFString?
        let status = withUnsafeMutablePointer(to: &cfStr) { ptr -> OSStatus in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, ptr)
        }
        guard status == noErr, let value = cfStr else { return nil }
        return value as String
    }
}

/// No-op fallback detector: never reports a meeting. Used when Core Audio inspection
/// is unavailable so the app runs normally with manual Quiet Mode available.
final class NoopMeetingDetector: MeetingDetecting, @unchecked Sendable {
    var state: MeetingState { .none }
    var isAvailable: Bool { false }
    func sample() {}
}
