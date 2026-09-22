import Foundation

public enum WorkspaceStartPlan {
    public static func name(
        supplied: String?, checkout: WorkspaceCheckout?, prompt: String
    ) -> String {
        if let supplied = WorkspaceName.given(supplied) { return supplied }
        if let checkout, let named = WorkspaceName.given(checkout.workspaceName) { return named }
        return WorkspaceName.given(Git.title(from: prompt)) ?? Git.title(from: "")
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
}
