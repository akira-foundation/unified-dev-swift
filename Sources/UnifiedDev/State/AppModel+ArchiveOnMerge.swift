import Core

extension AppModel {
    func noteCurrentPullRequest(_ pullRequest: PullRequest, for id: WorkspaceID) async {
        guard let store,
              let workspace = workspaces.first(where: { $0.id == id }),
              let repo = repo(for: workspace),
              !isArchiving(id) else { return }

        let seenOpen = try? await store.pullRequestSeenOpen(workspaceID: id)
        if let number = MergeArchivePolicy.seenOpenToRecord(pullRequest, recorded: seenOpen) {
            try? await store.recordPullRequestSeenOpen(number, workspaceID: id)
            return
        }

        let decision = MergeArchivePolicy.decide(
            isEnabled: SettingsLoader.load(repo: repo.path).archiveOnMerge,
            seenOpen: seenOpen,
            pullRequest: pullRequest,
            isAgentMidTurn: isAgentMidTurn(workspace)
        )
        switch decision {
        case .leave:
            return
        case .forget:
            try? await store.recordPullRequestSeenOpen(nil, workspaceID: id)
            return
        case .archiveNow, .archiveAfterTurn:
            guard (try? await store.takePullRequestSeenOpen(pullRequest.number, workspaceID: id)) == true,
                  !isArchiving(id) else { return }
        }

        if decision == .archiveAfterTurn {
            Log.archive.info(
                "\(workspace.name, privacy: .public) merged mid turn and will be archived when the turn ends"
            )
            mergeArchiveWaits.wait(for: id)
            return
        }
        await archiveOnMerge(workspace)
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
        case .archive:
            await archiveOnMerge(workspace)
        }
    }

    func settleMergeWaitsAfterTerminalActivity() {
        for id in mergeArchiveWaits.ids {
            guard let workspace = workspaces.first(where: { $0.id == id }),
                  !isAgentMidTurn(workspace) else { continue }
            Task { await archiveIfMergeWaiting(workspace, wasStopped: false) }
        }
    }

    private func archiveOnMerge(_ workspace: Workspace) async {
        guard let store, !isArchiving(workspace.id) else { return }
        if let objection = await WorkspaceArchiveSafety.objection(to: workspace, excusing: nil, store: store) {
            notice = Notice(
                message: "\(workspace.name) merged and was not archived. \(objection)",
                tone: .warning
            )
            return
        }
        Log.archive.info("\(workspace.name, privacy: .public) merged and is being archived")
        guard case .refused(let reason) = await archive(
            workspace, deleteBranch: nil, allowsConfirmation: false
        ) else { return }
        notice = Notice(
            message: "\(workspace.name) merged and was not archived. \(reason)",
            tone: .warning
        )
    }
}
