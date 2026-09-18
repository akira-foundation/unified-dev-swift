import Core

extension AppModel {
    func selectNextWorkspace(offset: Int) {
        let ordered = repos.flatMap { workspaces(in: $0) }
        guard !ordered.isEmpty else { return }
        guard let current = selection.workspaceID,
              let index = ordered.firstIndex(where: { $0.id == current }) else {
            selection = .workspace(ordered[0].id)
            return
        }
        let next = (index + offset + ordered.count) % ordered.count
        selection = .workspace(ordered[next].id)
    }

    func selectNextUnread() {
        let ordered = repos.flatMap { workspaces(in: $0) }
        guard let target = ordered.first(where: { $0.unread && $0.id != selection.workspaceID })
            ?? ordered.first(where: \.unread) else { return }
        selection = .workspace(target.id)
    }
}
