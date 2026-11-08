import Core

extension AppModel {
    func rename(_ workspace: Workspace, to name: String) async {
        guard let store, !name.isEmpty else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.name = name }
    }

    func togglePinned(_ workspace: Workspace) async {
        guard let store, !workspace.isOrchestrator else { return }
        _ = try? await store.update(workspaceID: workspace.id) { $0.pinned.toggle() }
    }

    func setOrchestrator(_ workspace: Workspace, _ isOrchestrator: Bool) async {
        guard let store else { return }
        let terminalAgents = isOrchestrator ? await TerminalSessionStore.shared.agentsInTerminals(of: workspace.id) : []
        let hasLiveWork = OrchestratorHandover.hasLiveWork(
            isMidTurn: isAgentMidTurn(workspace),
            hasBackgroundWork: workspaceModels[workspace.id]?.hasRunningBackgroundTasks ?? false,
            terminalAgents: terminalAgents
        )
        do {
            try await store.setOrchestrator(isOrchestrator, workspaceID: workspace.id, hasLiveWork: hasLiveWork)
        } catch WorkspaceError.orchestratorHasLiveWork {
            await handOverOrchestrator(from: workspace, terminalAgents: terminalAgents ?? [], store: store)
        } catch {
            notice = Notice(message: WorkspaceTrouble.complaint(about: error), tone: .warning)
        }
    }

    private func handOverOrchestrator(from workspace: Workspace, terminalAgents: [AgentKind], store: Store) async {
        do {
            guard let repo = repos.first(where: { $0.id == workspace.repoID }),
                  let prompt = try await store.orchestratorHandover(
                      from: workspace.id, terminalAgents: terminalAgents
                  ) else { return }
            let orchestrator = try await startWorkspace(
                in: repo, prompt: prompt, baseBranch: workspace.baseBranch,
                name: OrchestratorHandover.name(from: workspace), orchestrates: true
            )
            notice = Notice(message: OrchestratorHandover.notice(from: workspace, to: orchestrator))
        } catch {
            notice = Notice(message: WorkspaceTrouble.complaint(about: error), tone: .warning)
        }
    }

    func asksForOrchestrator(in repoID: RepoID) -> Bool {
        OrchestratorRole.asksAtCreation(repoID: repoID, workspaces: workspaces)
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
