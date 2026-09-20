import Foundation
import Testing
@testable import Core

@Suite("workspace_archive on a workspace the caller started", .tags(.persistence), .scratchDirectory)
struct WorkspaceArchiveStartedTests {
    private actor Calls {
        var orders: [WorkspaceArchiveOrder] = []
        func record(_ order: WorkspaceArchiveOrder) { orders.append(order) }
    }

    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: "workspace_archive", params: .object(arguments))
    }

    private func mine(in store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "Archive tool", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "Finished review", branch: "review",
            path: TestScratch.unique("mine"), baseBranch: "main"
        ))
    }

    private func started(by starter: Workspace, in store: Store) async throws -> Workspace {
        try await store.upsert(Workspace(
            repoID: starter.repoID, name: "Started by \(starter.name)", branch: "started-\(starter.id.rawValue)",
            path: TestScratch.unique("started"), baseBranch: "main",
            origin: .agent(parentWorkspaceID: starter.id, spawnToolUseID: "toolu_archive")
        ))
    }

    private func agent(_ workspace: Workspace) -> BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("my-session"), workspaceID: workspace.id, role: .workspace)
    }

    @Test("a workspace agent archives a workspace it started, by id, at once")
    func archivesOneItStarted() async throws {
        let store = try makeTestStore("archive-started")
        let mine = try await mine(in: store)
        let helper = try await started(by: mine, in: store)
        let calls = Calls()
        let tool = WorkspaceArchiveTool { order in
            await calls.record(order)
            return .archived
        }

        let result = await tool.call(request(["id": .string(helper.id.rawValue)]), as: agent(mine), store: store)

        #expect(!result.isError, "\(result.text)")
        #expect(result.text.contains("Archived '\(helper.name)'"))
        let orders = await calls.orders
        #expect(orders.map(\.workspace.id) == [helper.id])
        #expect(orders.map(\.afterTurnOf) == [nil])
    }

    @Test("a workspace it started with an agent still running there is refused")
    func startedAndStillRunning() async throws {
        let store = try makeTestStore("archive-started-busy")
        let mine = try await mine(in: store)
        let helper = try await started(by: mine, in: store)
        var busy = Session(workspaceID: helper.id, title: "Still going")
        busy.state = .running
        _ = try await store.upsert(busy)
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a busy started workspace reached the archive lifecycle")
            return .archived
        }

        let result = await tool.call(request(["id": .string(helper.id.rawValue)]), as: agent(mine), store: store)

        #expect(result.isError)
        #expect(result.text.contains("An agent is running"))
    }

    @Test("a workspace it did not start, and an id nothing has, get the same refusal")
    func notOneItStarted() async throws {
        let store = try makeTestStore("archive-not-started")
        let mine = try await mine(in: store)
        let theirs = try await store.upsert(Workspace(
            repoID: mine.repoID, name: "Somebody else's work", branch: "theirs",
            path: TestScratch.unique("theirs"), baseBranch: "main"
        ))
        let startedByThem = try await started(by: theirs, in: store)
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a workspace the caller did not start reached the archive lifecycle")
            return .archived
        }

        for named in [theirs.id.rawValue, startedByThem.id.rawValue, theirs.name, "no-such-id"] {
            let result = await tool.call(request(["id": .string(named)]), as: agent(mine), store: store)
            #expect(result.isError)
            #expect(result.text.contains("'\(named)' is not one you started"))
        }
        #expect(try await store.workspace(id: startedByThem.id)?.state == .active)
    }

    @Test("a workspace agent naming its own id is told to leave the id out")
    func namingItsOwnID() async throws {
        let store = try makeTestStore("archive-own-id")
        let mine = try await mine(in: store)
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("naming its own id reached the archive lifecycle")
            return .archived
        }

        let result = await tool.call(request(["id": .string(mine.id.rawValue)]), as: agent(mine), store: store)

        #expect(result.isError)
        #expect(result.text.contains("That is the workspace you are in"))
    }

    @Test("a workspace agent gets no force, no branch deletion and no other argument shape")
    func workspaceAgentArguments() async throws {
        let store = try makeTestStore("archive-arguments")
        let mine = try await mine(in: store)
        let helper = try await started(by: mine, in: store)
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a malformed call reached the archive lifecycle")
            return .archived
        }

        for arguments: [String: JSONValue] in [
            ["id": .integer(1)], ["id": .string(" ")], ["force": .bool(true)],
            ["id": .string(helper.id.rawValue), "force": .bool(true)],
            ["id": .string(helper.id.rawValue), "delete_branch": .bool(true)],
        ] {
            let result = await tool.call(request(arguments), as: agent(mine), store: store)
            #expect(result.isError)
            #expect(result.text.contains("no force option"))
        }
        #expect(try await store.workspace(id: helper.id)?.state == .active)
    }
}
