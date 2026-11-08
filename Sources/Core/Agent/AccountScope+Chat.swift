import Foundation

extension AccountScope {
    public static func chat(
        workspace: Workspace?, activeProfile: ProfileID, pinnedProfile: ProfileID?
    ) -> AccountScope {
        guard let workspace else { return AccountScope(profileID: pinnedProfile ?? activeProfile) }
        return AccountScope(workspaceID: workspace.id, repoID: workspace.repoID)
    }
}
