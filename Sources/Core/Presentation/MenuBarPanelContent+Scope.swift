import Foundation

extension MenuBarPanelContent.Input {
    public func scoped(to shown: [Workspace]) -> MenuBarPanelContent.Input {
        let ids = Set(shown.map(\.id))
        var scoped = self
        scoped.workspaces = workspaces.filter { ids.contains($0.id) }
        scoped.running = running.intersection(ids)
        scoped.waiting = waiting.intersection(ids)
        scoped.agentsByWorkspace = agentsByWorkspace.filter { ids.contains($0.key) }
        scoped.hasAgentsElsewhere = !running.subtracting(ids).isEmpty
        return scoped
    }
}
