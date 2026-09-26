import SwiftUI
import Core

struct WelcomeKeepAwake: View {
    @State private var sleepSwitch = SleepSwitch.shared
    @State private var keepAwake = KeepAwakeModel.shared

    var body: some View {
        WelcomeOfferRow(
            symbol: "bolt.badge.clock",
            headline: "Keep this Mac awake",
            detail: detail
        ) {
            control
        }
        .onAppear { sleepSwitch.refresh() }
    }

    private var detail: String {
        switch sleepSwitch.standing {
        case .ready:
            keepAwake.keepsLidClosed
                ? "A Keep Awake session now holds the lid too."
                : "Approved. Switch the lid option on whenever you want it."
        case .needsApproval:
            "Agents stop when the Mac sleeps. Holding the lid open needs a small helper you "
                + "approve in System Settings."
        case .unavailable(let reason):
            "This copy cannot install the helper: \(reason)"
        }
    }

    @ViewBuilder
    private var control: some View {
        switch sleepSwitch.standing {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.positive)
                .accessibilityLabel("Approved")
        case .needsApproval:
            Button("Set Up…") { setUp() }
        case .unavailable:
            EmptyView()
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
