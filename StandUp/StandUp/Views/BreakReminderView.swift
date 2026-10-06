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
    var canSnooze: Bool
    var onStartBreak: () -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void

    /// Drives the attention pulse; the controller toggles this.
    var pulse: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Full-screen dimming backdrop using a native dark material.
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()

            // Centered content card.
            VStack(spacing: 24) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: pulseActive)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Time to stand up")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                    Text("You've been actively working for \(workMinutesText).")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Take a short break away from the screen.")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    Button(action: onStartBreak) {
                        Text("Start break")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 12)
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.extraLarge)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start break")

                    if canSnooze {
                        Button(action: onSnooze) {
                            Text("Snooze 5 min")
                                .font(.title3)
                                .padding(.horizontal, 8)
                        }
                        .controlSize(.extraLarge)
                        .accessibilityLabel("Snooze five minutes")
                    }

                    Button(action: onSkip) {
                        Text("Skip this break")
                            .font(.title3)
                    }
                    .controlSize(.extraLarge)
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityLabel("Skip this break")
                }
                .padding(.top, 8)
            }
            .padding(48)
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: pulse)
    }

    private var pulseActive: Bool {
        reduceMotion ? false : pulse
    }

    private var workMinutesText: String {
        "\(workMinutes) minute\(workMinutes == 1 ? "" : "s")"
    }
}
