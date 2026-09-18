import Foundation

public enum WorkspaceStartPlan {
    public static func canStart(
        hasProject: Bool,
        prompt: String,
        hasCheckout: Bool,
        isChatWorkspace: Bool,
        isBusy: Bool
    ) -> Bool {
        guard hasProject, !isBusy else { return false }
        guard isChatWorkspace, !hasCheckout else { return true }
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func name(
        supplied: String?, checkout: WorkspaceCheckout?, prompt: String
    ) -> String {
        if let supplied, !supplied.isEmpty { return supplied }
        if let checkout { return checkout.workspaceName }
        return Git.title(from: prompt)
    }

    public static func terminalName(userSuppliedBranch: String?, claimedSea: String?) -> String? {
        if let userSuppliedBranch, !userSuppliedBranch.isEmpty { return userSuppliedBranch }
        return claimedSea
    }

    public static func unnamedName(
        isChatWorkspace: Bool, hasTask: Bool, userSuppliedBranch: String?, claimedSea: String?
    ) -> String? {
        guard isChatWorkspace else {
            return terminalName(userSuppliedBranch: userSuppliedBranch, claimedSea: claimedSea)
        }
        return hasTask ? nil : claimedSea
    }

    public static func carriedName(prompt: String, currentName: String) -> String {
        guard currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentName
        }
        let spoken = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return "" }
        return Git.title(from: spoken)
    }

    public static func carriedPrompt(name: String, currentPrompt: String) -> String {
        guard currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentPrompt
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func startNote(
        mode: WorkspaceStartMode, hasCheckout: Bool, name: String
    ) -> String {
        let agentless = "Nothing is sent to an agent."
        guard !hasCheckout else {
            return "The worktree stands on it and \(mode.openingSentence). " + agentless
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Leave it empty and Unified Dev names it for you. " + agentless
            : "This names the workspace and its branch. " + agentless
    }
}
