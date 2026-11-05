import Foundation

extension MenuBarPanelContent.Input {
    public func scoped(to shown: [Workspace]) -> MenuBarPanelContent.Input {
        let ids = Set(shown.map(\.id))
        var scoped = self
        scoped.workspaces = workspaces.filter { ids.contains($0.id) }
        scoped.running = running.intersection(ids)
        scoped.waiting = waiting.intersection(ids)
        let inWorkspaces = agentsByWorkspace.filter { ids.contains($0.key) }.values.reduce(0, +)
        scoped.runningAgents = inWorkspaces + (askIsWorking ? 1 : 0)
        return scoped
    }
}
