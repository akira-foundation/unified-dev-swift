import SwiftUI
import Core

struct WelcomeKeepAwakeRow: View {
    @State private var sleepSwitch = SleepSwitch.shared
    @State private var keepAwake = KeepAwakeModel.shared

    var body: some View {
        WelcomeToggleRow(
            symbol: "bolt.badge.clock",
            headline: "Keep this Mac awake",
            detail: detail,
            isOn: Binding(get: { isOn }, set: { wanted in MainActor.assumeIsolated { hold(wanted) } }),
            isEnabled: isAvailable
        )
        .onAppear { sleepSwitch.refresh() }
    }

    private var isOn: Bool { keepAwake.keepsLidClosed }

    private var isAvailable: Bool {
        if case .unavailable = sleepSwitch.standing { return false }
        return true
    }

    private var detail: String {
        switch sleepSwitch.standing {
        case .ready:
            isOn
                ? "A Keep Awake session now holds the lid too."
                : "Approved. Switch it on whenever you want a session to hold the lid open."
        case .needsApproval:
            "Agents stop when the Mac sleeps. Holding the lid open needs a small helper you "
                + "approve in System Settings."
        case .unavailable(let reason):
            "This copy cannot install the helper: \(reason)"
        }
    }

    private func hold(_ wanted: Bool) {
        guard wanted else {
            keepAwake.keepsLidClosed = false
            return
        }
        switch sleepSwitch.enable() {
        case .ready:
            keepAwake.keepsLidClosed = true
        case .needsApproval:
            keepAwake.keepsLidClosed = true
            sleepSwitch.openApprovalSettings()
        case .unavailable:
            keepAwake.keepsLidClosed = false
        }
    }
}
