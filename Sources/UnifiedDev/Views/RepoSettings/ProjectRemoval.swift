import Foundation
import Core

extension ProjectRemoval {
    static func confirmation(
        for repo: Repo, workspaces: [Workspace], runningAgents: Int, canvasLosses: [String]
    ) -> Confirmation {
        Confirmation(
            title: "Remove \(repo.name)?",
            message: consequences(workspaces: workspaces, runningAgents: runningAgents, canvasLosses: canvasLosses),
            confirmLabel: "Remove Project",
            cancelLabel: "Cancel"
        )
    }
}
