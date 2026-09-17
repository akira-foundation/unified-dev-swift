import Foundation
import Core

extension AppModel {
    func deliverWorkspaceMessage(_ message: WorkspaceMessage) async -> WorkspaceMessageDeliveryOutcome {
        guard let store else { return .refused("Unified Dev's database is not open.") }
        guard let targetID = message.target.workspaceID,
              let workspace = workspaces.first(where: { $0.id == targetID })
        else {
            return .refused("The workspace '\(message.target.workspace)' is not open in Unified Dev any more.")
        }

        let model = model(for: workspace)
        guard let chat = await model.chatForWorkspaceMessage(preferring: message.replySessionID) else {
            return .refused("Unified Dev could not open a chat in '\(workspace.name)' to put it in.")
        }

        let queued: WorkspaceMessage
        do {
            queued = try await store.enqueueWorkspaceMessage(message, into: chat)
        } catch {
            return .refused("Unified Dev could not queue it: \(error.readableMessage)")
        }

        await model.drainWorkspaceMessage(into: chat)
        return .sent((try? await store.workspaceMessage(id: queued.id)) ?? queued)
    }

    func cancelWorkspaceMessage(_ id: WorkspaceMessageID) async {
        guard let store else { return }
        guard let cancelled = try? await store.cancelWorkspaceMessage(id: id) else {
            notice = Notice(
                message: "That message had already gone to the other agent, so it was not cancelled."
            )
            return
        }
        if let workspaceID = cancelled.target.workspaceID, let sessionID = cancelled.target.sessionID,
           let transcript = existingModel(for: workspaceID)?.existingTranscript(for: sessionID) {
            await transcript.refreshQueue()
        }
        await tellSenderCancelled(cancelled)
    }

    func noteDeliveryCancelled(_ deliveryID: DeliveryID) async {
        guard let store,
              let message = try? await store.workspaceMessage(deliveryID: deliveryID),
              message.state == .cancelled
        else { return }
        await tellSenderCancelled(message)
    }

    func workspaceMessage(id: WorkspaceMessageID) async -> WorkspaceMessage? {
        try? await store?.workspaceMessage(id: id)
    }

    func revealWorkspace(_ id: WorkspaceID?) {
        guard let id, workspaces.contains(where: { $0.id == id }) else { return }
        selection = .workspace(id)
    }

    private func tellSenderCancelled(_ message: WorkspaceMessage) async {
        guard let sourceID = message.source.workspaceID,
              let source = workspaces.first(where: { $0.id == sourceID })
        else { return }
        await model(for: source).tellWorkspaceMessageCancelled(message)
    }
}
