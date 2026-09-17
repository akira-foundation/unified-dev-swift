import Foundation
@testable import Core

struct WorkspaceSayFixture {
    let store: Store
    let fixer: Workspace
    let fixerChat: Session
    let releaser: Workspace
    let releaserChat: Session

    var fixerIdentity: BridgeIdentity {
        BridgeIdentity(sessionID: fixerChat.id, workspaceID: fixer.id, role: .parent)
    }

    var releaserIdentity: BridgeIdentity {
        BridgeIdentity(sessionID: releaserChat.id, workspaceID: releaser.id, role: .parent)
    }

    var chats: [WorkspaceID: Session] { [fixer.id: fixerChat, releaser.id: releaserChat] }

    static func make(_ label: String) async throws -> WorkspaceSayFixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "apex", path: TestScratch.unique("repo")))
        let fixer = try await store.upsert(Workspace(
            repoID: repo.id, name: "fix-the-bug", branch: "apex/fix",
            path: TestScratch.unique("fixer"), baseBranch: "main"
        ))
        let releaser = try await store.upsert(Workspace(
            repoID: repo.id, name: "release", branch: "apex/release",
            path: TestScratch.unique("releaser"), baseBranch: "main"
        ))
        let fixerChat = try await store.upsert(Session(workspaceID: fixer.id, title: "Chat"))
        let releaserChat = try await store.upsert(Session(workspaceID: releaser.id, title: "Release"))
        return WorkspaceSayFixture(
            store: store, fixer: fixer, fixerChat: fixerChat,
            releaser: releaser, releaserChat: releaserChat
        )
    }
}

final class WorkspaceSayWindow: @unchecked Sendable {
    var sent: [WorkspaceMessage] = []
    let store: Store
    let chats: [WorkspaceID: Session]

    init(store: Store, chats: [WorkspaceID: Session]) {
        self.store = store
        self.chats = chats
    }

    func tool() -> WorkspaceSayTool {
        WorkspaceSayTool { [self] message in
            guard let id = message.target.workspaceID, let chat = chats[id] else {
                return .refused("No chat.")
            }
            guard let row = try? await store.enqueueWorkspaceMessage(message, into: chat) else {
                return .refused("The store said no.")
            }
            sent.append(row)
            return .sent(row)
        }
    }
}

func workspaceSay(
    _ text: String, to workspace: Workspace, as identity: BridgeIdentity, with tool: WorkspaceSayTool,
    store: Store
) async -> BridgeToolResult {
    await tool.call(
        MCPRequest(id: .number(1), method: "workspace_say", params: .object([
            "workspace": .string(workspace.id.rawValue), "message": .string(text),
        ])),
        as: identity,
        store: store
    )
}
