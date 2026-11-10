import Foundation

public extension ComposerControls {
    func runningPermissionMode(orchestrates: Bool) -> PermissionMode {
        OrchestratorToolGuard.permissionMode(permissionMode, orchestrates: orchestrates)
    }

    func permissionLabel(orchestrates: Bool) -> String {
        permissionChoice(runningPermissionMode(orchestrates: orchestrates), orchestrates: orchestrates).label
    }

    func permissionModeChoices(orchestrates: Bool) -> [PermissionModeChoice] {
        guard orchestrates else { return permissionModeChoices }
        return availablePermissionModes
            .filter { OrchestratorToolGuard.permissionMode($0) == $0 }
            .map { permissionChoice($0, orchestrates: true) }
    }

    private func permissionChoice(_ mode: PermissionMode, orchestrates: Bool) -> PermissionModeChoice {
        var choice = PermissionModeChoice(mode: mode, on: agentKind)
        guard orchestrates, agentKind == .claudeCode,
              OrchestratorToolGuard.claudeMode(mode, orchestrates: true) == OrchestratorToolGuard.claudeAskingMode else {
            return choice
        }
        choice.label = OrchestratorToolGuard.claudeAskingLabel
        choice.summary = OrchestratorToolGuard.claudeAskingSummary
        return choice
    }
}
