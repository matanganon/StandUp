import SwiftUI
import StandUpCore

/// The compact panel shown when the menu bar item is clicked.
struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let coord = model.coordinator
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("StandUp").font(.headline)
                Spacer()
                if model.isFastTesting {
                    Text("TEST").font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.orange.opacity(0.25), in: Capsule())
                }
            }

            // Status block
            statusBlock(coord)

            // Primary action
            primaryAction(coord)

            Divider()

            // Quiet mode
            quietModeMenu(coord)

            Divider()

            // Today stats
            VStack(alignment: .leading, spacing: 2) {
                Text("Today").font(.caption).foregroundStyle(.secondary)
                Text("\(coord.stats.completedBreaks) completed break\(coord.stats.completedBreaks == 1 ? "" : "s")")
                    .font(.callout)
                if coord.stats.snoozes > 0 {
                    Text("\(coord.stats.snoozes) snooze\(coord.stats.snoozes == 1 ? "" : "s")")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if coord.stats.skippedBreaks > 0 {
                    Text("\(coord.stats.skippedBreaks) skipped")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Divider()

            // Footer controls
            HStack {
                if coord.isPaused {
                    Button("Resume") { coord.resume() }
                } else {
                    Button("Pause") { coord.pause() }
                }
                Spacer()
                Button("Preview") { model.previewReminder() }
                    .help("Show the break reminder now")
                Button("Settings…") { openSettings() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder
    private func statusBlock(_ coord: BreakCoordinator) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch coord.state {
            case .working, .warning:
                Text("Next break").font(.caption).foregroundStyle(.secondary)
                Text(timeString(coord.remainingWork))
                    .font(.system(size: 30, weight: .semibold)).monospacedDigit()
                ProgressView(value: progress(coord))
                Text(statusLine(coord)).font(.callout).foregroundStyle(.secondary)
            case .snoozed:
                Text("Snoozed").font(.caption).foregroundStyle(.secondary)
                Text(timeString(coord.remainingWork))
                    .font(.system(size: 30, weight: .semibold)).monospacedDigit()
            case .due:
                Label("Break due", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3).foregroundStyle(.orange)
                Text("Time to stand up.").font(.callout).foregroundStyle(.secondary)
            case .deferredForMeeting:
                Label("Break due", systemImage: "mic.fill")
                    .font(.title3)
                Text("You're in a call — I'll remind you when it ends.")
                    .font(.callout).foregroundStyle(.secondary)
            case .breakInProgress:
                Text("Break in progress").font(.caption).foregroundStyle(.secondary)
                Text(timeString(coord.remainingBreak))
                    .font(.system(size: 30, weight: .semibold)).monospacedDigit()
                Text("Walk around, stretch, or get some water.")
                    .font(.callout).foregroundStyle(.secondary)
            case .paused:
                Label("Paused", systemImage: "pause.circle").font(.title3)
            }
        }
    }

    @ViewBuilder
    private func primaryAction(_ coord: BreakCoordinator) -> some View {
        switch coord.state {
        case .working, .warning, .snoozed:
            Button {
                coord.startBreak()
            } label: {
                Text("Take a break now").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .due, .deferredForMeeting:
            HStack {
                Button {
                    coord.startBreak()
                } label: {
                    Text("Start break").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                if coord.canSnooze {
                    Button("Snooze") { coord.snooze() }
                }
                Menu {
                    Button("Skip this break") { coord.skip() }
                } label: { Image(systemName: "ellipsis.circle") }
                .frame(width: 40)
            }
        case .breakInProgress:
            Button("End break early") { coord.skip() }
        case .paused:
            EmptyView()
        }
    }

    @ViewBuilder
    private func quietModeMenu(_ coord: BreakCoordinator) -> some View {
        if coord.isManualQuietActive {
            Button {
                coord.disableManualQuiet()
            } label: {
                Label("Turn off Quiet mode", systemImage: "bell.slash.fill")
            }
        } else {
            Menu {
                Button("30 minutes") { coord.enableManualQuiet(for: 30 * 60) }
                Button("1 hour") { coord.enableManualQuiet(for: 60 * 60) }
                Button("2 hours") { coord.enableManualQuiet(for: 2 * 60 * 60) }
                Button("Until turned off") { coord.enableManualQuiet(for: nil) }
            } label: {
                Label("Quiet mode", systemImage: "bell.slash")
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func progress(_ coord: BreakCoordinator) -> Double {
        let total = coord.settings.workInterval
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - coord.remainingWork) / total))
    }

    private func statusLine(_ coord: BreakCoordinator) -> String {
        if coord.isManualQuietActive { return "Working — Quiet mode on" }
        return "Working"
    }
}
