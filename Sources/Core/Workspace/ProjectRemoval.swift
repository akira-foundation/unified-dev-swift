import Foundation

public enum ProjectRemoval {
    public static func consequences(workspaces: [Workspace], runningAgents: Int) -> String {
        let active = workspaces.filter { $0.state == .active }.count

        var text = "Unified Dev forgets this project"
        switch active {
        case 0 where workspaces.isEmpty: text += "."
        case 0: text += " and its \(workspaces.count) archived workspace\(workspaces.count == 1 ? "" : "s")."
        default:
            text += ", its \(active) active workspace\(active == 1 ? "" : "s") and their transcripts."
        }

        if runningAgents == 1 {
            text += " An agent is working in one of them right now, and it is stopped."
        } else if runningAgents > 1 {
            text += " Agents are working in \(runningAgents) of them right now, and they are stopped."
        }

        text += " Nothing on disk is deleted: the repository stays where it is"
        if active > 0 {
            text += ", and the worktrees stay checked out, so they have to be removed with `git worktree remove` if they are no longer wanted"
        }
        return text + "."
    }
}
