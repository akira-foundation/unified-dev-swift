import Foundation
import Core

extension AppModel {
    func loadDrafts() async {
        guard let store else { return }
        guard let recovered = try? await WorkspaceDraftRecovery.settle(in: store) else {
            return drafts.adopt(((try? await store.workspaceDrafts()) ?? []).filter { $0.creatingAs == nil })
        }
        for key in recovered.finished.map(\.attachmentKey) where WorkspaceDraft.isStagingKey(key) {
            Task.detached(priority: .utility) { AttachmentStaging.discard(draftID: key) }
        }
        for draft in recovered.handedOver {
            let key = draft.attachmentKey
            guard WorkspaceDraft.isStagingKey(key),
                  let worktree = workspaces.first(where: { $0.id == draft.creatingAs })?.path else { continue }
            Task.detached(priority: .utility) { AttachmentStaging.handOver(draftID: key, into: worktree) }
        }
        drafts.adopt(recovered.kept)
    }

    func openDraft(in requested: Repo? = nil, prompt: String? = nil, asksForStartingPoint: Bool = false) {
        guard let repo = NewWorkspaceTarget.project(
            requested: requested?.id, selection: selection, workspaces: workspaces, repos: repos
        ) else { return }
        drafts.open(
            WorkspaceDraft(repoID: repo.id, startingPoint: .newBranch(from: repo.defaultBranch)),
            from: selection
        )
        if let prompt { receive(prompt, into: repo.id) }
        if asksForStartingPoint { drafts.askForOrigin(repo.id) }
        selection = .draft(repo.id)
    }

    func editDraft(_ repoID: RepoID, _ change: (inout WorkspaceDraft) -> Void) {
        drafts.edit(repoID, store: store, change)
    }

    func leaveDraft(from previous: SidebarSelection, to next: SidebarSelection) {
        guard let repoID = previous.draftRepoID, previous != next else { return }
        switch WorkspaceDraftRows.departure(
            hasContent: drafts.holdsWork(repoID),
            isCreating: drafts.isCreating(repoID),
            hasFailed: drafts.failure(for: repoID) != nil
        ) {
        case .keep:
            Task { await drafts.flush(repoID, store: store) }
        case .discard:
            forgetDraft(repoID)
        }
    }

    func discardDraft(_ repoID: RepoID) {
        guard !drafts.isCreating(repoID) else { return }
        let back = drafts.returnTarget(for: repoID) ?? .home
        forgetDraft(repoID)
        guard selection == .draft(repoID) else { return }
        selection = back
    }

    func forgetDraft(ofRemoved repoID: RepoID) {
        let wasOpen = selection == .draft(repoID)
        forgetDraft(repoID)
        if wasOpen { selection = .home }
    }

    func moveDraft(_ repoID: RepoID, to target: RepoID) {
        guard repoID != target, let draft = drafts.draft(for: repoID),
              let repo = repos.first(where: { $0.id == target }) else { return }
        switch WorkspaceDraftMove.decide(draft, to: repo, targetHasDraft: drafts.draft(for: target) != nil) {
        case .goTo(let existing):
            selection = .draft(existing)
        case .move(let moved):
            drafts.move(repoID, to: moved, store: store)
            selection = .draft(target)
        }
    }

    func prepareDraftControls(for repo: Repo) async {
        guard drafts.draft(for: repo.id)?.controls == nil else { return }
        let resolved = (try? await resolvedControls(for: repo)) ?? ComposerControls()
        var usesCLIChat = false
        if let store { usesCLIChat = await AppDefaults.load(from: store).terminalChat }
        let kept = WorkspaceDraftControls(resolved, usesCLIChat: usesCLIChat)
        drafts.edit(repo.id, store: store) { draft in
            guard draft.controls == nil else { return }
            draft.controls = kept
        }
    }

    func createFromDraft(_ repoID: RepoID, staged: StagedAttachments) async {
        guard let draft = drafts.draft(for: repoID), !drafts.isCreating(repoID),
              let repo = repos.first(where: { $0.id == repoID }) else { return }
        let submission = WorkspaceDraftSubmission(
            draft: draft, defaultBranch: repo.defaultBranch, warnedStale: drafts.staleWarning(for: repoID)
        )
        let id = WorkspaceID.new()
        drafts.beginCreating(repoID, as: id)
        await drafts.flush(repoID, store: store)
        do {
            let defaults = (try? await resolvedControls(for: repo)) ?? ComposerControls()
            let workspace = try await startWorkspace(
                in: repo,
                prompt: submission.prompt,
                baseBranch: submission.baseBranch,
                opensWith: submission.mode,
                controls: submission.controls(over: defaults),
                staged: staged,
                select: false,
                checkout: submission.checkout,
                id: id,
                acceptsStaleBase: submission.acceptsStaleBase
            )
            guard drafts.isCreating(repoID, as: id) else { return }
            let wasOpen = selection == .draft(repoID)
            forgetDraft(repoID)
            if wasOpen { selection = .workspace(workspace.id) }
            if let arrived = drafts.takeArrival(for: repoID) { openDraft(in: repo, prompt: arrived) }
        } catch {
            let trouble = await WorkspaceTrouble.creating(
                error, project: repo.name, projectPath: repo.path, baseBranch: submission.baseBranch
            )
            guard drafts.isCreating(repoID, as: id) else { return }
            drafts.fail(
                repoID, sentence: trouble.sentence,
                staleStart: trouble.warnsOfStaleBase ? draft.startingPoint : nil, store: store
            )
            if let arrived = drafts.takeArrival(for: repoID) { receive(arrived, into: repoID) }
        }
    }

    func flushDrafts() async {
        await drafts.flushAll(store: store)
    }

    func showsDraft(in repoID: RepoID) -> Bool {
        guard drafts.draft(for: repoID) != nil else { return false }
        return WorkspaceDraftRows.shows(
            hasContent: drafts.holdsWork(repoID),
            isOpen: selection == .draft(repoID),
            isCreating: drafts.isCreating(repoID),
            hasFailed: drafts.failure(for: repoID) != nil
        )
    }

    var shownDrafts: [RepoID] {
        repos.map(\.id).filter(showsDraft(in:))
    }

    func drawnPending(in repoID: RepoID) -> [PendingWorkspace] {
        WorkspaceDraftRows.drawnPending(
            pendingWorkspaces.filter { $0.repoID == repoID },
            creating: drafts.creatingWorkspaceIDs
        )
    }

    private func receive(_ text: String, into repoID: RepoID) {
        guard !drafts.isCreating(repoID) else { return drafts.holdArrival(text, for: repoID) }
        drafts.arriveQuietly(repoID)
        drafts.edit(repoID, store: store) { $0.prompt = WorkspaceDraft.receiving(text, into: $0.prompt) }
    }

    private func forgetDraft(_ repoID: RepoID) {
        if let key = drafts.draft(for: repoID)?.attachmentKey, WorkspaceDraft.isStagingKey(key) {
            PromptAttachmentStore.shared.clear(sessionID: key)
            Task.detached(priority: .utility) { AttachmentStaging.discard(draftID: key) }
        }
        drafts.remove(repoID, store: store)
    }
}
