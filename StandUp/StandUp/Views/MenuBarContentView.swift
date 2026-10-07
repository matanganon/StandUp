import AppKit
import SwiftUI
import StandUpCore

/// The compact panel shown when the menu bar item is clicked.
struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let coord = model.coordinator

        VStack(spacing: 14) {
            header(coord)
            statusCard(coord)
            primaryAction(coord)
            quickActions(coord)
            statsCard(coord)
            footer
        }
        .padding(16)
        .frame(width: 348)
        .background {
            LinearGradient(
                colors: [statusColor(coord).opacity(0.12), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func header(_ coord: BreakCoordinator) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.stand")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [statusColor(coord), statusColor(coord).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("StandUp")
                        .font(.headline)
                    if model.isFastTesting {
                        Text("TEST")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                Text("Healthy focus, one break at a time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor(coord))
                    .frame(width: 7, height: 7)
                Text(statusBadge(coord))
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
        }
    }

    private func statusCard(_ coord: BreakCoordinator) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            statusContent(coord)

            if coord.state == .working || coord.state == .warning {
                ProgressView(value: progress(coord))
                    .tint(statusColor(coord))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func statusContent(_ coord: BreakCoordinator) -> some View {
        switch coord.state {
        case .working, .warning:
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT BREAK")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Text(timeString(coord.remainingWork))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Label(statusLine(coord), systemImage: coord.isManualQuietActive ? "bell.slash.fill" : "bolt.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
            }
        case .snoozed:
            timerState(
                title: "SNOOZED",
                time: timeString(coord.remainingWork),
                icon: "moon.zzz.fill",
                color: .indigo
            )
        case .due:
            messageState(
                title: "Break due",
                message: "Time to stand up and reset.",
                icon: "figure.walk.motion",
                color: .orange
            )
        case .deferredForMeeting:
            messageState(
                title: "Break ready",
                message: "You're in a call — I'll remind you when it ends.",
                icon: "video.fill",
                color: .purple
            )
        case .breakInProgress:
            timerState(
                title: "BREAK IN PROGRESS",
                time: timeString(coord.remainingBreak),
                icon: "leaf.fill",
                color: .green
            )
            Text("Walk around, stretch, or get some water.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .paused:
            messageState(
                title: "Paused",
                message: "Your focus timer is waiting for you.",
                icon: "pause.fill",
                color: .secondary
            )
        }
    }

    private func timerState(title: String, time: String, icon: String, color: Color) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(time)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: Circle())
        }
    }

    private func messageState(title: String, message: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                Label("Take a break now", systemImage: "figure.walk")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .due, .deferredForMeeting:
            HStack(spacing: 8) {
                Button {
                    coord.startBreak()
                } label: {
                    Label("Start break", systemImage: "play.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if coord.canSnooze {
                    Button("Snooze") { coord.snooze() }
                        .controlSize(.large)
                }

                Menu {
                    Button("Skip this break") { coord.skip() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
        case .breakInProgress:
            Button("End break early") { coord.skip() }
                .frame(maxWidth: .infinity)
        case .paused:
            EmptyView()
        }
    }

    private func quickActions(_ coord: BreakCoordinator) -> some View {
        HStack(spacing: 8) {
            Button {
                coord.isPaused ? coord.resume() : coord.pause()
            } label: {
                QuickActionLabel(
                    title: coord.isPaused ? "Resume" : "Pause",
                    icon: coord.isPaused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(.plain)

            Button {
                model.previewReminder()
            } label: {
                QuickActionLabel(title: "Preview", icon: "eye.fill")
            }
            .buttonStyle(.plain)
            .help("Show the break reminder now")

            quietModeControl(coord)
        }
    }

    @ViewBuilder
    private func quietModeControl(_ coord: BreakCoordinator) -> some View {
        if coord.isManualQuietActive {
            Button {
                coord.disableManualQuiet()
            } label: {
                QuickActionLabel(title: "Quiet on", icon: "bell.slash.fill", isActive: true)
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                Button("30 minutes") { coord.enableManualQuiet(for: 30 * 60) }
                Button("1 hour") { coord.enableManualQuiet(for: 60 * 60) }
                Button("2 hours") { coord.enableManualQuiet(for: 2 * 60 * 60) }
                Divider()
                Button("Until turned off") { coord.enableManualQuiet(for: nil) }
            } label: {
                QuickActionLabel(title: "Quiet", icon: "bell.slash")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func statsCard(_ coord: BreakCoordinator) -> some View {
        HStack(spacing: 0) {
            StatItem(value: coord.stats.completedBreaks, label: "Breaks", icon: "checkmark.circle.fill", color: .green)
            statDivider
            StatItem(value: coord.stats.snoozes, label: "Snoozes", icon: "moon.fill", color: .indigo)
            statDivider
            StatItem(value: coord.stats.skippedBreaks, label: "Skipped", icon: "forward.fill", color: .orange)
        }
        .padding(.vertical, 10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var statDivider: some View {
        Divider()
            .frame(height: 28)
    }

    private var footer: some View {
        HStack {
            Button(action: showSettings) {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.plain)

            Spacer()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
    }

    /// Settings scenes in menu-bar-only apps do not always reactivate when an
    /// existing window is behind other applications. Activate the app and bring
    /// its regular titled window forward after SwiftUI has opened the scene.
    private func showSettings() {
        openSettings()
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows
                .first { window in
                    window.isVisible
                        && !(window is NSPanel)
                        && window.level == .normal
                        && window.styleMask.contains(.titled)
                }?
                .makeKeyAndOrderFront(nil)
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
        coord.isManualQuietActive ? "Quiet mode" : "Focusing"
    }

    private func statusBadge(_ coord: BreakCoordinator) -> String {
        switch coord.state {
        case .working, .warning: "Active"
        case .snoozed: "Snoozed"
        case .due: "Due"
        case .deferredForMeeting: "In a call"
        case .breakInProgress: "On break"
        case .paused: "Paused"
        }
    }

    private func statusColor(_ coord: BreakCoordinator) -> Color {
        switch coord.state {
        case .working: .blue
        case .warning, .due: .orange
        case .snoozed: .indigo
        case .deferredForMeeting: .purple
        case .breakInProgress: .green
        case .paused: .secondary
        }
    }
}

private struct QuickActionLabel: View {
    let title: String
    let icon: String
    var isActive = false

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? Color.accentColor : .primary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            isActive ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06))
        }
        .contentShape(Rectangle())
    }
}

private struct StatItem: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
