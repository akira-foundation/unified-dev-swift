import Foundation
import Testing
@testable import Core

@Suite("workspace_start asking to be told", .tags(.persistence), .scratchDirectory)
struct WorkspaceStartDoneWatchTests {
    private func tool(_ store: Store) -> WorkspaceStartTool {
        WorkspaceStartTool { _, repo, _, _ in
            let made = try await store.upsert(Workspace(
                repoID: repo.id, name: "helper", branch: "unifieddev/helper",
                path: TestScratch.unique("helper"), baseBranch: "main"
            ))
            _ = try await store.upsert(Session(workspaceID: made.id, title: "First"))
            return StartedWorkspaceSummary(
                workspaceID: made.id, name: made.name, branch: made.branch, path: made.path
            )
        }
    }

    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .number(1), method: "workspace_start", params: .object(arguments))
    }

    @Test("workspace_start with the flag watches the new workspace's first chat")
    func startWatchesTheFirstChat() async throws {
        let f = try await WorkspaceSayFixture.make("done-start")
        let identity = BridgeIdentity(sessionID: f.fixerChat.id, workspaceID: f.fixer.id, role: .workspace)

        let result = await tool(f.store).call(
            request(["prompt": .string("Write the changelog."), "notify_when_done": .bool(true)]),
            as: identity, store: f.store
        )

        #expect(!result.isError, "\(result.text)")
        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(true))
        #expect(answer["note"]?.stringValue?.contains("comes to rest") == true)
        let workspaceID = WorkspaceID(try #require(answer["workspace_id"]?.stringValue))
        let watch = try #require(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: workspaceID).first)
        #expect(watch.cause == .start)
        #expect(watch.watcherSessionID == f.fixerChat.id)
        let firstChat = try await f.store.sessions(workspaceID: workspaceID).first
        #expect(watch.target.sessionID == firstChat?.id)
    }

    @Test("without the flag nothing is watched")
    func withoutTheFlag() async throws {
        let f = try await WorkspaceSayFixture.make("done-start-without")
        let identity = BridgeIdentity(sessionID: f.fixerChat.id, workspaceID: f.fixer.id, role: .workspace)

        let result = await tool(f.store).call(
            request(["prompt": .string("Write the changelog.")]), as: identity, store: f.store
        )

        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(false))
        let workspaceID = WorkspaceID(try #require(answer["workspace_id"]?.stringValue))
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: workspaceID).isEmpty)
    }

    @Test("a promise the store cannot write is said in the answer, and the workspace still starts")
    func unrecordedWatchIsSaid() async throws {
        let f = try await WorkspaceSayFixture.make("done-start-unrecorded")
        let identity = BridgeIdentity(sessionID: f.fixerChat.id, workspaceID: f.fixer.id, role: .workspace)
        let raw = try SQLiteDatabase(path: f.store.path)
        try raw.execute("DROP TABLE workspace_done_watches;")

        let result = await tool(f.store).call(
            request(["prompt": .string("Write the changelog."), "notify_when_done": .bool(true)]),
            as: identity, store: f.store
        )

        #expect(!result.isError, "\(result.text)")
        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(false))
        #expect(answer["note"]?.stringValue?.contains("could not record notify_when_done") == true)
    }

    @Test("the owner's own client is told the flag was ignored, and the workspace still starts")
    func ownerClientIsTold() async throws {
        let f = try await WorkspaceSayFixture.make("done-start-owner")
        let project = try await f.store.repo(id: f.fixer.repoID)

        let result = await tool(f.store).call(
            request([
                "prompt": .string("Write the changelog."),
                "project": .string(try #require(project?.name)),
                "notify_when_done": .bool(true),
            ]),
            as: .owner, store: f.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(result.text.contains("notify_when_done was ignored"))
        let answer = try #require(JSONValue.parse(result.text))
        #expect(answer["notify_when_done"] == .bool(false))
    }
}
