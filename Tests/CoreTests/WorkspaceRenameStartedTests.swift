import Foundation
import Testing
@testable import Core

@Suite("workspace_rename on a workspace the caller started", .tags(.persistence), .scratchDirectory)
struct WorkspaceRenameStartedTests {
    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .number(1), method: "workspace_rename", params: .object(arguments))
    }

    private func seed(_ store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "test", branch: "unifieddev/redesign",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
    }

    private func started(by starter: Workspace, named name: String, in store: Store) async throws -> Workspace {
        try await store.upsert(Workspace(
            repoID: starter.repoID, name: name, branch: "unifieddev/started-\(UUID().uuidString)",
            path: TestScratch.unique("worktree"), baseBranch: "main",
            origin: .agent(parentWorkspaceID: starter.id, spawnToolUseID: "toolu_rename")
        ))
    }

    private func agent(_ workspace: Workspace) -> BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s-1"), workspaceID: workspace.id, role: .workspace)
    }

    @Test("a workspace agent renames one it started, by name or by id, and nothing else moves")
    func renamesOneItStarted() async throws {
        let store = try makeTestStore("rename-started")
        let mine = try await seed(store)
        let helper = try await started(by: mine, named: "Foxglove", in: store)
        let unrelated = try await store.upsert(Workspace(
            repoID: mine.repoID, name: "Foxglove", branch: "b3",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))

        let byName = await WorkspaceRenameTool().call(
            request(["name": .string("Sentry importer"), "workspace": .string("foxglove")]),
            as: agent(mine), store: store
        )
        #expect(!byName.isError, "\(byName.text)")
        #expect(try await store.workspace(id: helper.id)?.name == "Sentry importer")
        #expect(JSONValue.parse(byName.text)?["workspace_id"]?.stringValue == helper.id.rawValue)

        let byID = await WorkspaceRenameTool().call(
            request(["name": .string("Sentry importer, v2"), "workspace": .string(helper.id.rawValue)]),
            as: agent(mine), store: store
        )
        #expect(!byID.isError, "\(byID.text)")
        #expect(try await store.workspace(id: helper.id)?.name == "Sentry importer, v2")

        #expect(try await store.workspace(id: mine.id)?.name == "test")
        #expect(try await store.workspace(id: unrelated.id)?.name == "Foxglove")
    }

    @Test("a name two workspaces it started share is refused, and neither is touched")
    func startedAmbiguous() async throws {
        let store = try makeTestStore("rename-started-ambiguous")
        let mine = try await seed(store)
        let first = try await started(by: mine, named: "helper", in: store)
        let second = try await started(by: mine, named: "Helper", in: store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("helper")]),
            as: agent(mine), store: store
        )

        #expect(result.isError)
        #expect(result.text.contains(first.id.rawValue))
        #expect(result.text.contains(second.id.rawValue))
        #expect(try await store.workspace(id: first.id)?.name == "helper")
        #expect(try await store.workspace(id: second.id)?.name == "Helper")
    }
}
