import Foundation
import Core

extension AppModel {
    func noteWorkspaceTurnEnded(_ ending: WorkspaceTurnEnding, in session: Session) async {
        guard let workspaceID = session.workspaceID, !isArchiving(workspaceID) else { return }
        await settleWorkspaceDoneWatches(
            on: workspaceID, ending: ending, in: session.id, isSubagentChat: session.parentSessionID != nil
        )
    }

    func noteWorkspaceArchivedForWatchers(_ workspaceID: WorkspaceID) async {
        await settleWorkspaceDoneWatches(on: workspaceID, ending: .archived, in: nil, isSubagentChat: false)
    }

    private func settleWorkspaceDoneWatches(
        on workspaceID: WorkspaceID, ending: WorkspaceTurnEnding, in sessionID: SessionID?, isSubagentChat: Bool
    ) async {
        guard let store,
              let told = try? await store.settleWorkspaceDoneWatches(
                  on: workspaceID, ending: ending, in: sessionID, isSubagentChat: isSubagentChat
              )
        else { return }
        for chat in told {
            guard let watcherWorkspace = workspaces.first(where: { $0.id == chat.workspaceID }) else { continue }
            let transcript = model(for: watcherWorkspace).transcript(for: chat)
            await transcript.refreshQueue()
            await transcript.drain()
        }
    }
}
