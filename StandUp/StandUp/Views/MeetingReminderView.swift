import SwiftUI

/// The small, quiet meeting reminder. No sound, no actions required, auto-dismisses.
struct MeetingReminderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Break due")
                    .font(.headline)
                Text("You're in a call. I'll remind you again when it ends.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 320, height: 90)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Break due. You're in a call. StandUp will remind you again when it ends.")
    }
}
