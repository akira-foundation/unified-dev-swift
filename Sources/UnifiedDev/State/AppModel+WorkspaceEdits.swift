import Core

extension AppModel {
    func rename(_ workspace: Workspace, to name: String) async {
        guard let store, !name.isEmpty else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.name = name }
    }

    func togglePinned(_ workspace: Workspace) async {
        guard let store else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.pinned.toggle() }
    }

    func markRead(_ workspace: Workspace) async {
        guard workspace.unread else { return }
        await setUnread(workspace, false)
    }

    func setUnread(_ workspace: Workspace, _ unread: Bool) async {
        guard let store else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.unread = unread }
    }

    func setColour(_ workspace: Workspace, to hex: String?) async {
        guard let store else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.colour = hex }
    }
}
