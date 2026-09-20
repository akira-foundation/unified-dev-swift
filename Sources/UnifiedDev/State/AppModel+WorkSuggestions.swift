import Foundation
import Core

extension AppModel {
    func undecidedSuggestions(in workspaceID: WorkspaceID) -> Int {
        undecidedSuggestionCounts[workspaceID] ?? 0
    }

    func workSuggestions(in sessionID: SessionID) async -> TranscriptSuggestions {
        TranscriptSuggestions((try? await store?.workSuggestions(sessionID: sessionID)) ?? [])
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
        guard let store,
              let project = WorkSuggestionCard.draftProject(for: suggestion, workspaces: workspaces, repos: repos)
        else { return }
        do {
            let shown = try await WorkSuggestionLaunch.shown(project, store: store)
            openDraft(in: shown, prompt: WorkSuggestionBrief.task(from: suggestion.prompt))
        } catch {
            alert = AppAlert(title: "Could not bring \(project.name) back into the sidebar", message: error.readableMessage)
        }
    }
}
