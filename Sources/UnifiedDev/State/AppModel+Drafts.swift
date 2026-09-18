import Foundation
import Core

extension AppModel {
    func loadDrafts() async {
        guard let store else { return }
        drafts.adopt((try? await store.workspaceDrafts()) ?? [])
    }

    func openDraft(in requested: Repo? = nil, prompt: String? = nil, asksForStartingPoint: Bool = false) {
        guard let repo = NewWorkspaceTarget.project(
            requested: requested?.id, selection: selection, workspaces: workspaces, repos: repos
        ) else { return }
        drafts.open(
            WorkspaceDraft(repoID: repo.id, startingPoint: .newBranch(from: repo.defaultBranch)),
            from: selection
        )
        if let prompt {
            drafts.edit(repo.id, store: store) { $0.prompt = WorkspaceDraft.receiving(prompt, into: $0.prompt) }
        }
        if asksForStartingPoint { drafts.askForOrigin(repo.id) }
        selection = .draft(repo.id)
    }

    func editDraft(_ repoID: RepoID, _ change: (inout WorkspaceDraft) -> Void) {
        drafts.edit(repoID, store: store, change)
    }

    func leaveDraft(from previous: SidebarSelection, to next: SidebarSelection) {
        guard let repoID = previous.draftRepoID, previous != next else { return }
        let hasContent = drafts.draft(for: repoID)?.hasContent ?? false
        switch WorkspaceDraftRows.departure(hasContent: hasContent, isCreating: drafts.isCreating(repoID)) {
        case .keep:
            Task { await drafts.flush(repoID, store: store) }
        case .discard:
            forgetDraft(repoID)
        }
    }

    func discardDraft(_ repoID: RepoID) {
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
        let submission = WorkspaceDraftSubmission(draft: draft, defaultBranch: repo.defaultBranch)
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
                id: id
            )
            let wasOpen = selection == .draft(repoID)
            forgetDraft(repoID)
            if wasOpen { selection = .workspace(workspace.id) }
        } catch {
            let trouble = await WorkspaceTrouble.creating(
                error, project: repo.name, projectPath: repo.path, baseBranch: submission.baseBranch
            )
            drafts.fail(repoID, sentence: trouble.sentence)
        }
    }

    func flushDrafts() async {
        await drafts.flushAll(store: store)
    }

    func showsDraft(in repoID: RepoID) -> Bool {
        guard let draft = drafts.draft(for: repoID) else { return false }
        return WorkspaceDraftRows.shows(
            hasContent: draft.hasContent,
            isOpen: selection == .draft(repoID),
            isCreating: drafts.isCreating(repoID)
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

    private func forgetDraft(_ repoID: RepoID) {
        if let key = drafts.draft(for: repoID)?.attachmentKey {
            PromptAttachmentStore.shared.clear(sessionID: key)
            Task.detached(priority: .utility) { AttachmentStaging.discard(draftID: key) }
        }
        drafts.remove(repoID, store: store)
    }
}
