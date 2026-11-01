import SwiftUI
import Core

struct NewWorkspaceOrchestratorChip: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ComposerControlLabel(text: "Orchestrator", tint: Palette.textPrimary, isActive: isOn) {
                Image(systemName: SidebarRoleMark.orchestrator)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .help(isOn ? "Start this workspace as an ordinary one" : "Make this workspace the orchestrator")
        .accessibilityLabel("Orchestrator")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
