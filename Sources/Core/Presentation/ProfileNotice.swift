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

    public static func alreadyElsewhere(_ repo: Repo, active: ProfileID, profiles: [Profile]) -> String? {
        guard repo.profileID != active, let holder = profiles.first(where: { $0.id == repo.profileID }) else {
            return nil
        }
        return "\(repo.name) is already in the \(holder.name) profile. Switch to it, or move the project from there."
    }
}
