import Foundation
import Core

extension AppModel {
    func startObservingWorkSuggestions() {
        guard let store else { return }
        workSuggestionObservationTask?.cancel()
        workSuggestionObservationTask = Task { [weak self] in
            await self?.reloadUndecidedSuggestions()
            for await batch in store.changes(of: [.workSuggestions, .sessions]) {
                guard let self else { return }
                if batch.contains(.workSuggestions) { self.workSuggestionsRevision += 1 }
                await self.reloadUndecidedSuggestions()
            }
        }
    }

    func undecidedSuggestions(in workspaceID: WorkspaceID) -> Int {
        undecidedSuggestionCounts[workspaceID] ?? 0
    }

    func workSuggestion(id: WorkSuggestionID) async -> WorkSuggestion? {
        try? await store?.workSuggestion(id: id)
    }

    func workSuggestionContext(for suggestion: WorkSuggestion) async -> WorkSuggestionCard.Context {
        let chat = try? await store?.session(id: suggestion.sessionID)
        return .of(
            suggestion, workspaces: workspaces, repos: repos,
            chatIsSubagent: chat?.parentSessionID != nil
        )
    }

    func startSuggestion(_ id: WorkSuggestionID, as choice: WorkSuggestionLaunch.Choice) async {
        guard let store, let manager else { return }
        let launch = WorkSuggestionLaunch(
            start: { [weak self] order, project, identity, origin in
                guard let self else { throw AppNotReady.stillStartingUp }
                return try await self.startWorkspaceForBridge(order, in: project, from: identity, origin: origin)
            },
            crew: { [weak self] order, sessionID, workspaceID in
                guard let self else { return .refused("Unified Dev is still starting up.") }
                return await self.startCrewForBridge(order, from: sessionID, in: workspaceID)
            },
            admit: { path in await WorkSuggestionLaunch.admit(path, with: manager) }
        )
        _ = await launch.launch(id, as: choice, store: store)
    }

    func dismissSuggestion(_ id: WorkSuggestionID) async {
        _ = try? await store?.dismissWorkSuggestion(id: id)
    }

    func openStartedSuggestion(_ suggestion: WorkSuggestion) {
        switch WorkSuggestionCard.openTarget(for: suggestion) {
        case .workspace(let workspaceID):
            revealWorkspace(workspaceID)
        case .session(let sessionID):
            guard let workspaceID = suggestion.workspaceID else { return }
            selection = .crew(workspaceID, sessionID)
        case nil:
            return
        }
    }

    func openSuggestionAsDraft(_ suggestion: WorkSuggestion) async {
        guard var repo = WorkSuggestionCard.draftProject(for: suggestion, workspaces: workspaces, repos: repos)
        else { return }
        if repo.hidden, let store, let shown = try? await store.update(repoID: repo.id, { $0.hidden = false }) {
            repo = shown
        }
        openDraft(in: repo, prompt: WorkSuggestionBrief.task(from: suggestion.prompt))
    }

    private func reloadUndecidedSuggestions() async {
        guard let store else { return }
        let counts = (try? await store.undecidedWorkSuggestionCounts()) ?? [:]
        if counts != undecidedSuggestionCounts { undecidedSuggestionCounts = counts }
    }
}
