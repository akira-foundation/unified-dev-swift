import Foundation

public enum SessionRolePrompt {
    public static func text(_ text: String, workspaceID: WorkspaceID?, orchestrates: Bool, opensSession: Bool) -> String {
        guard workspaceID == nil else {
            return OrchestratorToolGuard.prompt(text, orchestrates: orchestrates, opensSession: opensSession)
        }
        guard opensSession else { return text }
        return AskConversation.instructions + "\n\n" + text
    }
}
