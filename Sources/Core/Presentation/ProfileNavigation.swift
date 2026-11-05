import Foundation

public enum ProfileNavigation {
    public static func owner(
        of selection: SidebarSelection, workspaces: [Workspace], repos: [Repo]
    ) -> ProfileID? {
        switch selection {
        case .home, .ask:
            nil
        case .draft(let repoID):
            repos.first { $0.id == repoID }?.profileID
        case .archived(let id), .workspace(let id), .subagent(let id, _), .subagentCall(let id, _), .crew(let id, _):
            ProfileScope.profile(of: id, workspaces: workspaces, repos: repos)
        }
    }

    public static func activation(
        for selection: SidebarSelection, active: ProfileID, workspaces: [Workspace], repos: [Repo]
    ) -> ProfileID? {
        guard let owner = owner(of: selection, workspaces: workspaces, repos: repos), owner != active else {
            return nil
        }
        return owner
    }

    public static func activation(forHome filter: HomeFilter, active: ProfileID, repos: [Repo]) -> ProfileID? {
        let owners = Set(repos.filter { filter.projects.contains($0.id) }.map(\.profileID))
        guard owners.count == 1, let owner = owners.first, owner != active else { return nil }
        return owner
    }

    public static func maySwitch(to target: ProfileID, from active: ProfileID, among profiles: [Profile]) -> Bool {
        target != active && profiles.contains { $0.id == target }
    }

    public static func landing(
        in profile: ProfileID, memory: ProfileMemory, workspaces: [Workspace], repos: [Repo]
    ) -> SidebarSelection {
        let live = ProfileScope.workspaces(workspaces, repos: repos, in: profile).map(\.id)
        return memory.landing(for: profile, live: Set(live))
    }

    public static func settled(
        _ selection: SidebarSelection,
        active: ProfileID,
        memory: ProfileMemory,
        workspaces: [Workspace],
        repos: [Repo]
    ) -> SidebarSelection? {
        guard activation(for: selection, active: active, workspaces: workspaces, repos: repos) != nil else {
            return nil
        }
        return landing(in: active, memory: memory, workspaces: workspaces, repos: repos)
    }

    public static func narrowed(_ filter: HomeFilter, to profile: ProfileID, repos: [Repo]) -> HomeFilter {
        var narrowed = filter
        narrowed.projects.formIntersection(ProfileScope.repos(repos, in: profile).map(\.id))
        return narrowed
    }
}
