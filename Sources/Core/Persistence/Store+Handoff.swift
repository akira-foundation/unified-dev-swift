import Foundation

extension Store {
    func handoffPrompt(
        _ text: String, session: Session, deliveredSeq: Int?, workspacePath: String, contextWindow: Int?
    ) async throws -> String {
        guard try handoffIsDue(sessionID: session.id, deliveredSeq: deliveredSeq) else { return text }
        var worktree: ConversationHandoff.Worktree?
        if let workspaceID = session.workspaceID, let workspace = try workspace(id: workspaceID) {
            worktree = await HandoffWorktree.read(path: workspacePath, base: workspace.baseBranch)
        }
        return try handoffTurn(
            text, sessionID: session.id, deliveredSeq: deliveredSeq,
            worktree: worktree, contextWindow: contextWindow
        )
    }
}
