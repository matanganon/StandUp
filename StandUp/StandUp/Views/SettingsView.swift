import SwiftUI
import StandUpCore

/// Native Settings scene with General / Reminders / Meetings tabs.
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsTab(model: model)
                .tabItem { Label("General", systemImage: "gear") }
            ReminderSettingsTab(model: model)
                .tabItem { Label("Reminders", systemImage: "bell") }
            MeetingSettingsTab(model: model)
                .tabItem { Label("Meetings", systemImage: "video") }
        }
        .frame(width: 460)
        .padding(.vertical, 8)
    }
}

private struct GeneralSettingsTab: View {
    @Bindable var model: AppModel
    @ObservedObject private var launch: LaunchAtLoginService

    init(model: AppModel) {
        self.model = model
        self.launch = model.launchAtLogin
    }

    private let workOptions: [Double] = [20, 25, 30, 45, 60]
    private let breakOptions: [Double] = [1, 2, 3, 5]

    var body: some View {
        Form {
            Picker("Work interval", selection: Binding(
                get: { minutesSelection(model.settings.workInterval, options: workOptions) },
                set: { if let v = $0 { model.settings.workInterval = v * 60 } }
            )) {
                ForEach(workOptions, id: \.self) { Text("\(Int($0)) min").tag(Optional($0)) }
            }

            Picker("Break duration", selection: Binding(
                get: { minutesSelection(model.settings.breakDuration, options: breakOptions) },
                set: { if let v = $0 { model.settings.breakDuration = v * 60 } }
            )) {
                ForEach(breakOptions, id: \.self) { Text("\(Int($0)) min").tag(Optional($0)) }
            }

            Toggle("Show seconds in menu bar", isOn: $model.settings.showSecondsInMenuBar)

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { launch.isEnabled },
                set: { launch.setEnabled($0) }
            ))
            if launch.status == .requiresApproval {
                HStack(spacing: 6) {
                    Text("Approval needed in System Settings.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open…") { launch.openSystemSettings() }
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launch.refresh() }
    }

    private func minutesSelection(_ seconds: TimeInterval, options: [Double]) -> Double? {
        let m = seconds / 60
        return options.contains(m) ? m : options.first
    }
}

private struct ReminderSettingsTab: View {
    @Bindable var model: AppModel

    private let warnOptions: [Double] = [1, 2, 3, 5]
    private let snoozeOptions: [Double] = [5, 10, 15]
    private let idleOptions: [Double] = [30, 60, 120]
    private let naturalOptions: [Double] = [3, 5, 10]

    var body: some View {
        Form {
            Toggle("Play sound when a break is due", isOn: $model.settings.soundEnabled)

            Picker("Warning before break", selection: Binding(
                get: { model.settings.warningThreshold / 60 },
                set: { model.settings.warningThreshold = $0 * 60 }
            )) {
                ForEach(warnOptions, id: \.self) { Text("\(Int($0)) min").tag($0) }
            }

            Picker("Snooze duration", selection: Binding(
                get: { model.settings.snoozeDuration / 60 },
                set: { model.settings.snoozeDuration = $0 * 60 }
            )) {
                ForEach(snoozeOptions, id: \.self) { Text("\(Int($0)) min").tag($0) }
            }

            Stepper("Maximum snoozes: \(model.settings.maxSnoozes)",
                    value: $model.settings.maxSnoozes, in: 0...5)

            Picker("Idle pause threshold", selection: Binding(
                get: { model.settings.idlePauseThreshold },
                set: { model.settings.idlePauseThreshold = $0 }
            )) {
                ForEach(idleOptions, id: \.self) { Text("\(Int($0)) sec").tag($0) }
            }

            Picker("Natural break threshold", selection: Binding(
                get: { model.settings.naturalBreakThreshold / 60 },
                set: { model.settings.naturalBreakThreshold = $0 * 60 }
            )) {
                ForEach(naturalOptions, id: \.self) { Text("\(Int($0)) min").tag($0) }
            }

            Toggle("Auto-complete break after inactivity",
                   isOn: $model.settings.autoCompleteOnInactivity)
        }
        .formStyle(.grouped)
    }
}

private struct MeetingSettingsTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Toggle("Automatic meeting detection",
                   isOn: $model.settings.automaticMeetingDetection)
                .disabled(!model.isMeetingDetectionAvailable)
            Toggle("Quiet reminders during meetings",
                   isOn: $model.settings.quietMeetingReminders)
            Toggle("Remind aggressively when a meeting ends",
                   isOn: $model.settings.aggressiveReminderAfterMeeting)

            Divider()

            HStack {
                Text("Current status")
                Spacer()
                Text(model.meetingStatusText)
                    .foregroundStyle(.secondary)
            }
            if !model.isMeetingDetectionAvailable {
                Text("Core Audio call detection isn't available on this system. Use Quiet mode from the menu when you're in a call.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
