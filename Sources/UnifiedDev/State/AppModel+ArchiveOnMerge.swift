import Core

extension AppModel {
    func noteCurrentPullRequest(_ pullRequest: PullRequest, for id: WorkspaceID) async {
        guard let store,
              let workspace = workspaces.first(where: { $0.id == id }),
              let repo = repo(for: workspace),
              !isArchiving(id) else { return }

        let decision = try? await MergeArchiveRead.note(
            pullRequest,
            workspaceID: id,
            isEnabled: SettingsLoader.load(repo: repo.path).archiveOnMerge,
            isAgentMidTurn: isAgentMidTurn(workspace),
            store: store
        )
        switch decision {
        case .archiveNow:
            await archiveOnMerge(workspace)
        case .archiveAfterTurn:
            Log.archive.info(
                "\(workspace.name, privacy: .public) merged mid turn and will be archived when the turn ends"
            )
            mergeArchiveWaits.wait(for: id, pullRequest: pullRequest.number)
        case .leave, .forget, nil:
            break
        }
    }

    func archiveIfMergeWaiting(_ workspace: Workspace, wasStopped: Bool) async {
        let settlement = mergeArchiveWaits.settle(
            workspace.id, isAgentMidTurn: isAgentMidTurn(workspace), wasStopped: wasStopped
        )
        switch settlement {
        case .notWaiting, .keepWaiting:
            return
        case .dropStopped:
            notice = Notice(
                message: "\(workspace.name) merged while its agent was working. You stopped that "
                    + "turn, so it was not archived.",
                tone: .warning
            )
        case .archive(let number):
            guard let store,
                  (try? await store.takePullRequestSeenOpen(number, workspaceID: workspace.id)) == true
            else { return }
            await archiveOnMerge(workspace)
        }
    }

    func settleMergeWaitsAfterTerminalActivity() {
        let running = TerminalSessionStore.shared.runningWorkspaceIDs
        let ended = terminalRunningWorkspaceIDs.subtracting(running)
        terminalRunningWorkspaceIDs = running
        for id in ended.intersection(mergeArchiveWaits.ids) {
            guard let workspace = workspaces.first(where: { $0.id == id }) else { continue }
            Task { await archiveIfMergeWaiting(workspace, wasStopped: false) }
        }
    }

    private func archiveOnMerge(_ workspace: Workspace) async {
        guard let store, !isArchiving(workspace.id) else { return }
        if await TerminalSessionStore.shared.isRunningCommand(in: workspace.id) {
            refuseArchiveOnMerge(workspace, because: "A command is still running in one of its terminals.")
            return
        }
        if let objection = await WorkspaceArchiveSafety.objection(to: workspace, excusing: nil, store: store) {
            refuseArchiveOnMerge(workspace, because: objection)
            return
        }
        Log.archive.info("\(workspace.name, privacy: .public) merged and is being archived")
        guard case .refused(let reason) = await archive(
            workspace, deleteBranch: nil, allowsConfirmation: false
        ) else { return }
        refuseArchiveOnMerge(workspace, because: reason)
    }

    private func refuseArchiveOnMerge(_ workspace: Workspace, because reason: String) {
        notice = Notice(
            message: "\(workspace.name) merged and was not archived. \(reason)",
            tone: .warning
        )
    }
}
