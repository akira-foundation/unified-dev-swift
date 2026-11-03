import Core

extension AppModel {
    func noteCurrentPullRequest(_ pullRequest: PullRequest, for id: WorkspaceID) async {
        guard let store,
              let workspace = workspaces.first(where: { $0.id == id }),
              let repo = repo(for: workspace),
              !isArchiving(id) else { return }

        let isCommandRunning = pullRequest.isMerged ? await isRunningCommand(in: id) : false
        let decision = try? await MergeArchiveRead.note(
            pullRequest,
            workspaceID: id,
            isEnabled: SettingsLoader.load(repo: repo.path).archiveOnMerge,
            isAgentMidTurn: isAgentMidTurn(workspace),
            isCommandRunning: isCommandRunning,
            store: store
        )
        if let decision {
            mergeArchiveWaits.record(decision, for: id, pullRequest: pullRequest.number)
            watchMergeWaits()
        }
        switch decision {
        case .archiveNow:
            mergeArchiveCommandNotices.remove(id)
            await archiveOnMerge(workspace)
        case .archiveAfterTurn:
            Log.archive.info(
                "\(workspace.name, privacy: .public) merged mid turn and will be archived when the turn ends"
            )
        case .waitForCommand:
            guard mergeArchiveCommandNotices.insert(id).inserted else { return }
            notice = Notice(
                message: "\(workspace.name) merged. It will be archived once the command still "
                    + "running in it ends.",
                tone: .information
            )
        case .leave, .forget, nil:
            break
        }
    }

    func archiveIfMergeWaiting(_ workspace: Workspace, wasStopped: Bool) async {
        let isMidTurn = isAgentMidTurn(workspace)
        let isCommandRunning = if wasStopped || isMidTurn { false } else { await isRunningCommand(in: workspace.id) }
        let settlement = mergeArchiveWaits.settle(
            workspace.id, isAgentMidTurn: isMidTurn, isCommandRunning: isCommandRunning, wasStopped: wasStopped
        )
        switch settlement {
        case .notWaiting, .keepWaiting:
            return
        case .dropStopped:
            try? await store?.recordPullRequestSeenOpen(nil, workspaceID: workspace.id)
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

    private func isRunningCommand(in id: WorkspaceID) async -> Bool {
        if existingModel(for: id)?.hasRunningBackgroundTasks == true { return true }
        return await TerminalSessionStore.shared.isRunningCommand(in: id)
    }

    private func watchMergeWaits() {
        guard mergeArchiveWatch == nil, !mergeArchiveWaits.ids.isEmpty else { return }
        mergeArchiveWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: MergeArchiveWaits.recheckInterval)
                guard let self else { return }
                await self.settleMergeWaits()
                if self.mergeArchiveWaits.ids.isEmpty {
                    self.mergeArchiveWatch = nil
                    return
                }
            }
        }
    }

    private func settleMergeWaits() async {
        for id in mergeArchiveWaits.ids {
            guard let workspace = workspaces.first(where: { $0.id == id }) else {
                mergeArchiveWaits.forget(id)
                continue
            }
            await archiveIfMergeWaiting(workspace, wasStopped: false)
        }
    }

    private func archiveOnMerge(_ workspace: Workspace) async {
        guard let store, !isArchiving(workspace.id) else { return }
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
