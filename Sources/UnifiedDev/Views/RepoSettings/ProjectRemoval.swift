import Foundation
import Core

extension ProjectRemoval {
    static func confirmation(
        for repo: Repo, workspaces: [Workspace], runningAgents: Int
    ) -> Confirmation {
        Confirmation(
            title: "Remove \(repo.name)?",
            message: consequences(workspaces: workspaces, runningAgents: runningAgents),
            confirmLabel: "Remove Project",
            cancelLabel: "Cancel"
        )
    }
}
