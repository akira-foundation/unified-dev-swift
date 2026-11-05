import Foundation

public enum ProfileNotice {
    public static func title(_ title: String, profile: Profile?, active: ProfileID) -> String {
        guard let profile, profile.id != active else { return title }
        return "\(profile.name): \(title)"
    }

    public static func profile(
        of batch: [WorkspaceID], workspaces: [Workspace], repos: [Repo]
    ) -> ProfileID? {
        let owners = batch.map { ProfileScope.profile(of: $0, workspaces: workspaces, repos: repos) }
        guard let first = owners.first, let owner = first, owners.allSatisfy({ $0 == owner }) else { return nil }
        return owner
    }
}
