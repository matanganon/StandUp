import SwiftUI
import StandUpCore

/// The menu bar item label: SF Symbol per state + monospaced countdown text.
struct MenuBarLabelView: View {
    let label: BreakCoordinator.MenuBarLabel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
            Text(label.text)
                .monospacedDigit()
        }
        .accessibilityLabel(label.accessibilityDescription)
    }

    private var symbolName: String {
        switch label.kind {
        case .working: return "timer"
        case .warning: return "timer.circle"
        case .due: return "exclamationmark.triangle.fill"
        case .dueInMeeting: return "mic.fill"
        case .breakRunning: return "figure.walk"
        case .paused: return "pause.circle"
        }
    }
}
