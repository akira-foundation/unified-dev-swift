import Core

extension WorkspaceModel {
    var canIgnoreSetupFailure: Bool {
        !isRunningSetup && workspace.setupState.transition(on: .failureIgnored).moves
    }

    func ignoreSetupFailure() {
        guard canIgnoreSetupFailure, let store else { return }
        let id = workspace.id
        Task { [weak self] in
            _ = try? await store.update(workspaceID: id) { $0.apply(.failureIgnored) }
            await self?.refreshSetupState()
        }
    }
}
