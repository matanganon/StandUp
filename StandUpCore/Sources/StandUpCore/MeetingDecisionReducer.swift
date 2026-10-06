import Foundation

/// A single raw observation of one process's audio activity at a point in time.
public struct AudioProcessSignal: Equatable, Sendable {
    public var bundleID: String?
    public var isRunningInput: Bool
    public var isRunningOutput: Bool
    public init(bundleID: String?, isRunningInput: Bool, isRunningOutput: Bool) {
        self.bundleID = bundleID
        self.isRunningInput = isRunningInput
        self.isRunningOutput = isRunningOutput
    }
}

/// Classification of a bundle id against the centralized sets.
enum AppKind {
    case communication
    case browser
    case other
}

/// Pure, deterministic reducer that turns a timeline of raw audio-process signals into
/// a debounced, sticky `MeetingState`. No system calls — fed by the detector or tests.
///
/// Rules implemented (see spec §17–§21):
/// - Known communication app with input → meeting after enter-debounce.
/// - Known communication app with sustained output-only → likely meeting (mic muted).
/// - Browser output alone is NOT a meeting; browser input establishes a meeting and
///   keeps it sticky while output continues (mic-mute grace).
/// - Unknown process with input → protected audio activity (quiet).
/// - Exit requires no qualifying signal for exit-debounce (plus browser sticky grace).
public struct MeetingDecisionReducer {

    public struct Config: Sendable {
        public var enterDebounce: TimeInterval
        public var exitDebounce: TimeInterval
        public var browserStickyGrace: TimeInterval
        public var outputOnlySustain: TimeInterval
        public init(
            enterDebounce: TimeInterval = Constants.Meeting.enterDebounce,
            exitDebounce: TimeInterval = Constants.Meeting.exitDebounce,
            browserStickyGrace: TimeInterval = Constants.Meeting.browserStickyGrace,
            outputOnlySustain: TimeInterval = Constants.Meeting.outputOnlySustain
        ) {
            self.enterDebounce = enterDebounce
            self.exitDebounce = exitDebounce
            self.browserStickyGrace = browserStickyGrace
            self.outputOnlySustain = outputOnlySustain
        }
    }

    private let config: Config
    private let ownBundleID: String?

    // Internal timeline state.
    private var publishedState: MeetingState = .none
    /// When a candidate qualifying signal was first continuously observed.
    private var candidateSince: Date?
    private var candidateBundleID: String?
    private var candidateIsProtected: Bool = false
    /// When a qualifying signal was last observed (for exit debounce).
    private var lastQualifyingSignal: Date?
    /// For browsers: when microphone input was last seen (sticky history).
    private var lastBrowserMicInput: Date?
    /// For comm apps: when output-only was first continuously seen.
    private var outputOnlySince: Date?

    public init(config: Config = Config(), ownBundleID: String? = nil) {
        self.config = config
        self.ownBundleID = ownBundleID
    }

    public var state: MeetingState { publishedState }

    private func kind(of bundleID: String?) -> AppKind {
        guard let id = bundleID else { return .other }
        if Constants.communicationAppBundleIDs.contains(id) { return .communication }
        if Constants.browserBundleIDs.contains(id) { return .browser }
        return .other
    }

    /// Describes a single qualifying candidate derived from the current signal set.
    private struct Qualifier {
        var bundleID: String?
        var isProtected: Bool // true => protectedAudioActivity rather than likelyMeeting
    }

    /// Advance the reducer with the full set of process signals observed at `now`.
    @discardableResult
    public mutating func update(signals: [AudioProcessSignal], now: Date) -> MeetingState {
        // Exclude our own process.
        let relevant = signals.filter { $0.bundleID != ownBundleID }

        // Track browser mic history for stickiness.
        for s in relevant where kind(of: s.bundleID) == .browser && s.isRunningInput {
            lastBrowserMicInput = now
        }

        let qualifier = computeQualifier(relevant, now: now)

        if let q = qualifier {
            lastQualifyingSignal = now
            // Debounce entry: a candidate must be stable for enterDebounce.
            if candidateSince == nil
                || candidateBundleID != q.bundleID
                || candidateIsProtected != q.isProtected {
                candidateSince = now
                candidateBundleID = q.bundleID
                candidateIsProtected = q.isProtected
            }
            if let since = candidateSince, now.timeIntervalSince(since) >= config.enterDebounce {
                publishedState = q.isProtected
                    ? .protectedAudioActivity(appBundleIdentifier: q.bundleID)
                    : .likelyMeeting(appBundleIdentifier: q.bundleID)
            } else if publishedState.isQuieting {
                // Keep an already-published state while a (possibly different) candidate debounces.
            }
        } else {
            candidateSince = nil
            candidateBundleID = nil
            candidateIsProtected = false
            // Exit debounce.
            if publishedState.isQuieting {
                let last = lastQualifyingSignal ?? .distantPast
                if now.timeIntervalSince(last) >= config.exitDebounce {
                    publishedState = .none
                }
            }
        }
        return publishedState
    }

    /// Decide whether the current signal set qualifies as a meeting/protected state.
    private mutating func computeQualifier(_ signals: [AudioProcessSignal], now: Date) -> Qualifier? {
        // 1. Known communication app with microphone input → strongest signal.
        if let comm = signals.first(where: { kind(of: $0.bundleID) == .communication && $0.isRunningInput }) {
            outputOnlySince = nil
            return Qualifier(bundleID: comm.bundleID, isProtected: false)
        }

        // 2. Known communication app with sustained output-only (mic muted during call).
        if let commOut = signals.first(where: { kind(of: $0.bundleID) == .communication && $0.isRunningOutput }) {
            if outputOnlySince == nil { outputOnlySince = now }
            if let s = outputOnlySince, now.timeIntervalSince(s) >= config.outputOnlySustain {
                return Qualifier(bundleID: commOut.bundleID, isProtected: false)
            }
            // Not sustained yet; fall through to other rules but remember timing.
        } else {
            outputOnlySince = nil
        }

        // 3. Browser with microphone input → meeting.
        if let browserMic = signals.first(where: { kind(of: $0.bundleID) == .browser && $0.isRunningInput }) {
            return Qualifier(bundleID: browserMic.bundleID, isProtected: false)
        }

        // 4. Browser output + recent mic history → sticky meeting (mic muted in a call).
        if let browserOut = signals.first(where: { kind(of: $0.bundleID) == .browser && $0.isRunningOutput }) {
            if let micSeen = lastBrowserMicInput,
               now.timeIntervalSince(micSeen) <= config.browserStickyGrace {
                return Qualifier(bundleID: browserOut.bundleID, isProtected: false)
            }
            // Browser output alone with no recent mic → NOT a meeting (e.g. YouTube).
        }

        // 5. Unknown process with microphone input → protected audio activity (quiet).
        if let unknownMic = signals.first(where: { kind(of: $0.bundleID) == .other && $0.isRunningInput }) {
            return Qualifier(bundleID: unknownMic.bundleID, isProtected: true)
        }

        return nil
    }
}
