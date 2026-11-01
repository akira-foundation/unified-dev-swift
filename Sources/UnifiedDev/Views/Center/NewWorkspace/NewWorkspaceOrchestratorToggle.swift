import SwiftUI

struct NewWorkspaceOrchestratorToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text("Make this workspace the orchestrator")
            Text("It plans and starts other workspaces, and never edits its own worktree.")
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
