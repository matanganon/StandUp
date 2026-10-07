import SwiftUI

/// The aggressive break reminder as a full-screen overlay on the active display.
///
/// It dims the screen with a native translucent material (the app behind stays visible,
/// dimmed) and centers the message and actions. It is a *soft blocker*: the overlay
/// window captures mouse clicks so the user cannot keep working underneath, but it does
/// not lock the screen, does not intercept system shortcuts (Cmd+Tab, Force Quit still
/// work), does not manipulate the mouse or keyboard, and always offers visible actions.
struct BreakReminderView: View {
    var workMinutes: Int
    var breakMinutes: Int
    var snoozeMinutes: Int
    var canSnooze: Bool
    var onStartBreak: () -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void

    /// Drives the attention pulse; the controller toggles this.
    var pulse: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.58))

                LinearGradient(
                    colors: [Color.accentColor.opacity(0.2), .clear, Color.indigo.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 26) {
                HStack {
                    Label("SCREEN RESET", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.accentColor)

                    Spacer()

                    Label("\(breakMinutesText) recommended", systemImage: "timer")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 36) {
                    ShoulderRollIllustration(highlighted: pulse)
                        .frame(width: 220, height: 175)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Step away. Come back refreshed.")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("You've been actively working for \(workMinutesText). A short reset helps you change posture and rest your eyes.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.74))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            SessionMetric(
                                icon: "laptopcomputer",
                                value: "\(workMinutes) min",
                                label: "Focused"
                            )
                            SessionMetric(
                                icon: "figure.walk",
                                value: breakMinutesText,
                                label: "Reset"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    BreakTip(
                        icon: "eye.fill",
                        title: "Rest your eyes",
                        detail: "Look at something far away for 20 seconds."
                    )
                    BreakTip(
                        icon: "figure.walk.motion",
                        title: "Change posture",
                        detail: "Stand up, relax your shoulders, and take a few steps."
                    )
                    BreakTip(
                        icon: "wind",
                        title: "Slow down",
                        detail: "Take three slow breaths away from the display."
                    )
                }

                Divider()
                    .overlay(.white.opacity(0.12))

                HStack(spacing: 18) {
                    Button(action: onStartBreak) {
                        Label("Start \(breakMinutesText) break", systemImage: "play.fill")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 12)
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.extraLarge)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start break")

                    if canSnooze {
                        Button(action: onSnooze) {
                            Label("Snooze \(snoozeMinutes) min", systemImage: "clock.arrow.circlepath")
                                .font(.title3)
                        }
                        .controlSize(.extraLarge)
                        .accessibilityLabel("Snooze \(snoozeMinutes) minutes")
                    }

                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.title3.weight(.medium))
                    }
                    .controlSize(.extraLarge)
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityLabel("Skip this break")
                }
                }
                .padding(36)
                .frame(width: min(920, max(0, geometry.size.width - 64)))
                .background {
                    RadialGradient(
                        colors: [.black.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 620
                    )
                    .blur(radius: 40)
                    .allowsHitTesting(false)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: pulse)
    }

    private var workMinutesText: String {
        "\(workMinutes) minute\(workMinutes == 1 ? "" : "s")"
    }

    private var breakMinutesText: String {
        "\(breakMinutes) min"
    }
}

private struct SessionMetric: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BreakTip: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

/// Static exercise cue in the same glass-and-accent language as the menu.
private struct ShoulderRollIllustration: View {
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(
                                highlighted ? Color.accentColor.opacity(0.7) : .white.opacity(0.1),
                                lineWidth: highlighted ? 2 : 1
                            )
                    }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 18, y: 8)

                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 68, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(height: 145)

            Label(
                "Roll shoulders forward, then backward",
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stand up and roll your shoulders forward, then backward")
    }
}
