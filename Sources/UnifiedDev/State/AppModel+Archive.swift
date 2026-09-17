import Core

extension AppModel {
    func archiveCleanup() async -> ArchiveCleanup {
        guard let store, var footprints = try? await store.archivedFootprints() else {
            return ArchiveCleanup(footprints: [])
        }

        var localBranches: [RepoID: Set<String>] = [:]
        for repo in repos where footprints.contains(where: { $0.workspace.repoID == repo.id }) {
            guard let branches = try? await Git.branches(of: repo.path) else { continue }
            localBranches[repo.id] = Set(branches)
        }
        for index in footprints.indices {
            let workspace = footprints[index].workspace
            footprints[index].branchIsLocal = localBranches[workspace.repoID]?.contains(workspace.branch)
        }
        return ArchiveCleanup(footprints: footprints)
    }

    func databaseSize() async -> DatabaseSize? {
        guard let store else { return nil }
        return try? await store.databaseSize()
    }

    @discardableResult
    func deleteArchived(_ ids: [WorkspaceID]) async -> ArchiveDeletionOutcome {
        guard let store, !ids.isEmpty else { return .deleted(0) }
        let removed: Int
        do {
            removed = try await store.deleteArchivedWorkspaces(ids: ids)
        } catch {
            return .refused(complaint: WorkspaceTrouble.complaint(about: error))
        }
        guard removed > 0 else { return .deleted(0) }

        if let open = selection.archivedWorkspaceID, ids.contains(open) {
            selection = .home
        }
        for id in ids {
            workspaceModels[id]?.teardown()
            workspaceModels[id] = nil
        }
        invalidateArchived()
        return .deleted(removed)
    }

    func compactDatabase() async {
        guard let store else { return }
        try? await store.compactDatabase()
    }

    @discardableResult
    func archive(
        _ workspace: Workspace,
        deleteBranch: Bool? = nil,
        alwaysConfirm: Bool = false,
        allowsConfirmation: Bool = true,
        presentConfirmation: ((ArchiveRequest) -> Void)? = nil
    ) async -> WorkspaceArchiveOutcome {
        guard let manager, let repo = repo(for: workspace) else {
            Log.archive.error(
                "asked to archive \(workspace.name, privacy: .public), but the app has no manager or no project for it"
            )
            return .refused("Unified Dev cannot archive this workspace because its project is unavailable.")
        }
        guard !isArchiving(workspace.id) else {
            return .refused("This workspace is already being archived. Check workspace_list shortly.")
        }

        var hazards = ArchiveHazards(
            isAgentRunning: isRunning(workspace),
            isPullRequestMerged: isPullRequestMerged(workspace),
            isDeletingBranch: deleteBranch ?? SettingsLoader.load(repo: repo.path).deleteBranchOnArchive
        )

        let report: WorkspaceSafetyReport
        do {
            report = try await manager.safetyReport(workspace: workspace, repo: repo)
        } catch {
            let trouble = await WorkspaceTrouble.archiving(
                error,
                workspace: workspace.name,
                path: workspace.path,
                baseBranch: workspace.baseBranch
            )
            let request = ArchiveRequest(
                workspace: workspace,
                report: WorkspaceSafetyReport(),
                deleteBranch: deleteBranch,
                problem: "Unified Dev could not check this workspace for unsaved work. \(trouble.sentence)",
                hazards: hazards
            )
            if allowsConfirmation { offerArchiveConfirmation(request, present: presentConfirmation) }
            return .refused(archiveRefusal(request))
        }

        hazards.isAgentRunning = isRunning(workspace) || isAwaitingPermission(workspace)
        let isSafe = report.isSafeToDiscard(
            deletingBranch: hazards.isDeletingBranch,
            isPullRequestMerged: hazards.isPullRequestMerged
        )

        guard isSafe, !hazards.isAgentRunning, !alwaysConfirm else {
            let request = ArchiveRequest(
                workspace: workspace, report: report, deleteBranch: deleteBranch, hazards: hazards
            )
            if allowsConfirmation { offerArchiveConfirmation(request, present: presentConfirmation) }
            return .refused(archiveRefusal(request))
        }

        return await performArchive(
            workspace,
            repo: repo,
            deleteBranch: deleteBranch,
            force: false,
            report: report,
            hazards: hazards,
            allowsConfirmation: allowsConfirmation,
            presentConfirmation: presentConfirmation
        )
    }

    func bookArchiveForBridge(of workspace: Workspace, after sessionID: SessionID) -> WorkspaceArchiveOutcome {
        bookArchive(of: workspace.id, after: sessionID)
        Log.archive.info(
            "\(workspace.name, privacy: .public) is booked to be archived when its agent's turn ends"
        )
        return .requested
    }

    func archiveIfRequested(
        _ workspace: Workspace, endedIn sessionID: SessionID, wasStopped: Bool = false
    ) async {
        guard takeArchiveBooking(of: workspace.id, endedIn: sessionID) else { return }
        guard let store else { return }

        if wasStopped {
            Log.archive.notice(
                "the booked archive of \(workspace.name, privacy: .public) was dropped: its turn was stopped by hand"
            )
            notice = Notice(
                message: "\(workspace.name) had asked to be archived when its agent finished. You "
                    + "stopped that turn, so nothing was archived and the request is dropped."
            )
            return
        }

        if let objection = await WorkspaceArchiveSafety.objection(
            to: workspace, excusing: nil, store: store
        ) {
            Log.archive.notice(
                "the booked archive of \(workspace.name, privacy: .public) was refused: \(objection, privacy: .public)"
            )
            notice = Notice(
                message: "\(workspace.name) asked to be archived when its agent finished, and it "
                    + "was not. \(objection)"
            )
            return
        }

        switch await archive(workspace, deleteBranch: false, allowsConfirmation: false) {
        case .archived, .requested:
            break
        case .refused(let reason):
            notice = Notice(
                message: "\(workspace.name) asked to be archived when its agent finished, and it "
                    + "was not. \(reason)"
            )
        }
    }

    private func isPullRequestMerged(_ workspace: Workspace) -> Bool {
        let pullRequest = workspaceModels[workspace.id]?.pullRequest
            ?? WorkspacePullRequests.shared.pullRequest(for: workspace.id)
        return pullRequest?.isMerged ?? false
    }

    func confirmArchive(
        _ request: ArchiveRequest,
        presentConfirmation: ((ArchiveRequest) -> Void)? = nil
    ) async {
        if pendingArchive?.id == request.id { pendingArchive = nil }
        guard let repo = repo(for: request.workspace) else {
            Log.archive.error(
                "confirmed the archive of \(request.workspace.name, privacy: .public), but its project is gone"
            )
            return
        }
        await performArchive(
            request.workspace,
            repo: repo,
            deleteBranch: request.deleteBranch,
            force: true,
            report: request.problem == nil ? request.report : nil,
            hazards: request.hazards,
            presentConfirmation: presentConfirmation
        )
    }

    func cancelPendingArchive() {
        pendingArchive = nil
    }

    private func offerArchiveConfirmation(
        _ request: ArchiveRequest, present: ((ArchiveRequest) -> Void)?
    ) {
        if let present {
            present(request)
        } else {
            pendingArchive = request
        }
    }

    @discardableResult
    private func performArchive(
        _ workspace: Workspace,
        repo: Repo,
        deleteBranch: Bool?,
        force: Bool,
        report: WorkspaceSafetyReport?,
        hazards: ArchiveHazards,
        allowsConfirmation: Bool = true,
        presentConfirmation: ((ArchiveRequest) -> Void)?
    ) async -> WorkspaceArchiveOutcome {
        guard let manager else {
            Log.archive.error(
                "archiving \(workspace.name, privacy: .public) stopped before it began: no workspace manager"
            )
            return .refused("Unified Dev is still starting up. Try again in a moment.")
        }

        guard hideFromSidebar(workspace.id) else {
            return .refused("This workspace is already being archived. Check workspace_list shortly.")
        }
        workspaceModels[workspace.id]?.stopEverything()

        let departure = ArchiveNavigation.destination(leaving: selection, archiving: workspace.id)
        if let departure { selection = departure }

        do {
            try await manager.archive(
                workspace: workspace,
                repo: repo,
                deleteBranch: deleteBranch,
                force: force,
                isPullRequestMerged: hazards.isPullRequestMerged
            )
            if let home = ArchiveNavigation.destination(leaving: selection, archiving: workspace.id) {
                selection = home
            }
            await TerminalSessionStore.shared.discard(workspaceID: workspace.id)
            workspaceModels[workspace.id]?.teardown()
            forgetWorkspace(workspace.id)
            invalidateArchived()
            await offerUndo(of: workspace, repo: repo, report: report)
            if let path = report?.preservedFolderPath {
                notice = Notice(
                    message: "\(workspace.name) was archived. Its folder at `\(path)` and its branch "
                        + "were kept because Git no longer recognizes the folder as a worktree. "
                        + "The archive script was skipped.",
                    dismissal: .untilDismissed
                )
            }
            Log.archive.info("archived \(workspace.name, privacy: .public)")
            return .archived
        } catch let error as WorkspaceError {
            await undoOptimisticArchive(workspace)
            switch error {
            case .archiveScriptFailed(let status, let output):
                Log.archive.error(
                    "the archive script for \(workspace.name, privacy: .public) exited \(status), so nothing was removed"
                )
                alert = AppAlert(
                    title: "The archive script failed",
                    message: "\u{201C}\(workspace.name)\u{201D} is still here: its worktree and "
                        + "its branch are untouched. Any agent it was running has been stopped.\n\n"
                        + "The script exited with status \(status).\n\n"
                        + String(output.trimmingCharacters(in: .whitespacesAndNewlines).suffix(1_000))
                )
            case .unsafeToArchive(let fresh):
                Log.archive.notice(
                    "\(workspace.name, privacy: .public) changed between the check and the archive, so it is being asked about again"
                )
                let request = ArchiveRequest(
                    workspace: workspace, report: fresh, deleteBranch: deleteBranch, hazards: hazards
                )
                if allowsConfirmation {
                    offerArchiveConfirmation(request, present: departure == nil ? presentConfirmation : nil)
                }
                return .refused(archiveRefusal(request))
            default:
                Log.archive.error(
                    "could not archive \(workspace.name, privacy: .public): \(error.readableMessage, privacy: .public)"
                )
                return .refused(await reportArchiveFailure(error, workspace: workspace))
            }
            return .refused("The archive script failed. Its worktree and branch were kept. Check Unified Dev's alert for the script output.")
        } catch {
            await undoOptimisticArchive(workspace)
            Log.archive.error(
                "could not archive \(workspace.name, privacy: .public): \(error.readableMessage, privacy: .public)"
            )
            return .refused(await reportArchiveFailure(error, workspace: workspace))
        }
    }

    private func archiveRefusal(_ request: ArchiveRequest) -> String {
        if let problem = request.problem { return problem }
        let reasons = request.losses + request.notes
        guard !reasons.isEmpty else { return "Confirm this archive in Unified Dev." }
        return "Archiving would discard \(reasons.joined(separator: "; ")). Resolve this or review it in Unified Dev."
    }

    private func reportArchiveFailure(_ error: any Error, workspace: Workspace) async -> String {
        let trouble = await WorkspaceTrouble.archiving(
            error,
            workspace: workspace.name,
            path: workspace.path,
            baseBranch: workspace.baseBranch
        )
        alert = AppAlert(title: "Could not archive the workspace", message: trouble.sentence)
        return trouble.sentence
    }

    private func undoOptimisticArchive(_ workspace: Workspace) async {
        restoreToSidebar(workspace)
        await reload()
    }

    private func offerUndo(
        of workspace: Workspace, repo: Repo, report: WorkspaceSafetyReport?
    ) async {
        guard let manager, undoManager != nil else { return }
        guard let report, report.isRestorableFromBranch else { return }
        guard SettingsLoader.load(repo: repo.path).archiveScript == nil else { return }
        guard await manager.canRestore(workspace: workspace, repo: repo) else { return }
        registerArchiveUndo(workspace, repo: repo)
    }

    private func registerArchiveUndo(_ workspace: Workspace, repo: Repo) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.beginRestore(of: workspace, repo: repo) }
        }
        undoManager.setActionName("Archive Workspace")
    }

    private func beginRestore(of workspace: Workspace, repo: Repo) {
        Task { await restore(workspace) }
    }

    func openArchived(_ workspace: Workspace) {
        model(for: workspace)
        selection = .archived(workspace.id)
    }

    func open(workspaceID id: WorkspaceID) async {
        if workspaces.contains(where: { $0.id == id }) {
            selection = .workspace(id)
            return
        }
        guard let archived = await archivedWorkspaces().first(where: { $0.id == id }) else { return }
        openArchived(archived)
    }

    func restoreSource(for workspace: Workspace) async -> RestoreSource? {
        guard let manager, let repo = repo(for: workspace) else { return nil }
        return await manager.restoreSource(workspace: workspace, repo: repo)
    }

    func restore(_ workspace: Workspace) async {
        guard let manager else { return }
        guard let repo = repo(for: workspace) else {
            alert = AppAlert(
                title: "Could not bring \(workspace.name) back",
                message: "Its project is no longer in Unified Dev, so there is no repository to cut a "
                    + "worktree from. Add the project again and try once more."
            )
            return
        }
        guard !restoring.contains(workspace.id) else { return }

        restoring.insert(workspace.id)
        defer { restoring.remove(workspace.id) }

        do {
            let outcome = try await manager.restore(workspace: workspace, repo: repo)
            invalidateArchived()
            await reload()
            selection = .workspace(outcome.workspace.id)
            Log.archive.info("restored \(workspace.name, privacy: .public)")

            if let from = outcome.relocatedFrom {
                notice = Notice(
                    message: "\(outcome.workspace.name) came back to a different place. "
                        + "Something else is at `\(from)`, so the worktree was rebuilt at "
                        + "`\(outcome.workspace.path)`.",
                    dismissal: .untilDismissed
                )
            }
        } catch {
            Log.archive.error(
                "could not restore \(workspace.name, privacy: .public): \(error.readableMessage, privacy: .public)"
            )
            let trouble = await WorkspaceTrouble.restoring(
                error,
                workspace: workspace.name,
                branch: workspace.branch,
                project: repo.name,
                projectPath: repo.path
            )
            alert = AppAlert(
                title: "Could not bring \(workspace.name) back",
                message: trouble.sentence
            )
        }
    }
}
