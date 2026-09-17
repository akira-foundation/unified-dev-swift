import SwiftUI
import Core

struct WelcomeKeepAwake: View {
    @State private var sleepSwitch = SleepSwitch.shared
    @State private var keepAwake = KeepAwakeModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                Text("Keep this Mac awake with the lid closed")
                    .font(Typo.displayHeading)
                    .foregroundStyle(Palette.textPrimary)

                Text(
                    "Agents stop when the Mac sleeps, and closing the lid sleeps it whatever an "
                        + "app asks for. Unified Dev can hold it open, but only through a small helper "
                        + "macOS makes you approve."
                )
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: Metrics.spacing) {
                standing

                Text(
                    "Unified Dev works without this. Keep Awake still holds the Mac open while the lid "
                        + "is up, and Settings has this switch again under Menu Bar."
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { sleepSwitch.refresh() }
    }

    @ViewBuilder
    private var standing: some View {
        switch sleepSwitch.standing {
        case .ready:
            Label {
                Text(keepAwake.keepsLidClosed
                    ? "Approved. A Keep Awake session now holds the lid too."
                    : "Approved. Switch the lid option on whenever you want it.")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.positive)
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
        case .needsApproval:
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Button("Set Up Keep Awake") { setUp() }
                    .buttonStyle(.borderedProminent)
                Text("System Settings opens on Login Items, where Unified Dev's helper is waiting to be allowed.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
        case .unavailable(let reason):
            Text("This copy of Unified Dev cannot install the helper: \(reason)")
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setUp() {
        switch sleepSwitch.enable() {
        case .ready:
            keepAwake.keepsLidClosed = true
        case .needsApproval:
            keepAwake.keepsLidClosed = true
            sleepSwitch.openApprovalSettings()
        case .unavailable:
            break
        }
    }
}
