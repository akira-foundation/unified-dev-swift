import Foundation
import Testing
@testable import Core

struct WorkspaceArchiveToolTests {
    @Test("archive is offered to the owner and to a workspace agent, and is never self-approved")
    func permissions() {
        let tool = WorkspaceArchiveTool { _ in .archived }
        let toolbox = BridgeToolbox(handlers: [tool])
        #expect(toolbox.handler(named: "workspace_archive", for: .owner) != nil)
        #expect(toolbox.handler(named: "workspace_archive", for: .workspace) != nil)
        #expect(toolbox.tools(for: .workspace).map(\.name).contains("workspace_archive"))
        #expect(!BridgeToolApproval.selfApproved.contains("workspace_archive"))
        #expect(!BridgeToolApproval.isSelfApproved(
            toolName: "mcp__unifieddev-workspace-bridge__workspace_archive"
        ))
    }

    @Test("the owner needs an exact id and never gets force or branch deletion")
    func ownerArguments() async throws {
        let (store, workspace) = try await fixture()
        let calls = ArchiveCalls()
        let tool = WorkspaceArchiveTool { order in
            await calls.record(order)
            return .archived
        }
        for arguments: [String: JSONValue] in [
            [:], ["id": .integer(1)], ["id": .string(" ")],
            ["id": .string(workspace.name)],
            ["id": .string(workspace.id.rawValue), "force": .bool(true)],
            ["id": .string(workspace.id.rawValue), "delete_branch": .bool(true)],
        ] {
            let result = await tool.call(request(arguments), as: .owner, store: store)
            #expect(result.isError)
        }
        #expect(await calls.orders.isEmpty)
    }

    @Test("a workspace agent naming nothing gets its own workspace, and naming one it did not start gets nothing")
    func workspaceIsolation() async throws {
        let (store, mine) = try await fixture()
        let theirs = try await second(in: store)
        let calls = ArchiveCalls()
        let tool = WorkspaceArchiveTool { order in
            await calls.record(order)
            return .requested
        }
        let identity = BridgeIdentity(
            sessionID: SessionID("my-session"), workspaceID: mine.id, role: .workspace
        )

        for named in [theirs.id.rawValue, theirs.name] {
            let result = await tool.call(request(["id": .string(named)]), as: identity, store: store)
            #expect(result.isError)
            #expect(result.text.contains("is not one of those ids"))
        }
        let own = await tool.call(request(["id": .string(mine.id.rawValue)]), as: identity, store: store)
        #expect(own.isError)
        #expect(own.text.contains("That is the workspace you are in"))
        #expect(await calls.orders.isEmpty)

        let result = await tool.call(request([:]), as: identity, store: store)
        #expect(!result.isError)
        #expect(await calls.orders.map(\.workspace.id) == [mine.id])
        #expect(try await store.workspace(id: theirs.id)?.state == .active)
    }

    @Test("a token naming a workspace that has gone is refused rather than guessed at")
    func workspaceOnTheTokenHasGone() async throws {
        let (store, _) = try await fixture()
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a caller with no live workspace reached the archive lifecycle")
            return .archived
        }
        let identity = BridgeIdentity(
            sessionID: SessionID("s"), workspaceID: WorkspaceID("gone"), role: .workspace
        )
        let result = await tool.call(request([:]), as: identity, store: store)
        #expect(result.isError)
        #expect(result.text.contains("no longer in Unified Dev"))
    }

    @Test("a workspace agent's call books cleanup for the end of its own turn")
    func deferredCleanup() async throws {
        let (store, workspace) = try await fixture()
        var session = Session(workspaceID: workspace.id, title: "Doing the work")
        session.state = .running
        session = try await store.upsert(session)
        let calls = ArchiveCalls()
        let tool = WorkspaceArchiveTool { order in
            await calls.record(order)
            return .requested
        }
        let identity = BridgeIdentity(
            sessionID: session.id, workspaceID: workspace.id, role: .workspace
        )
        let result = await tool.call(request([:]), as: identity, store: store)

        #expect(!result.isError)
        #expect(await calls.orders.map(\.afterTurnOf) == [session.id])
        #expect(result.text.contains("requested, not done"))
        #expect(result.text.contains("Nothing has been removed"))
        #expect(!result.text.contains("Archived '"))
        #expect(try await store.workspace(id: workspace.id)?.state == .active)
    }

    @Test("the owner's own client is acted on at once, waiting for no turn")
    func ownerIsNotDeferred() async throws {
        let (store, workspace) = try await fixture()
        let calls = ArchiveCalls()
        let tool = WorkspaceArchiveTool { order in
            await calls.record(order)
            return .archived
        }
        let result = await tool.call(
            request(["id": .string(workspace.id.rawValue)]), as: .owner, store: store
        )
        #expect(!result.isError)
        #expect(await calls.orders.map(\.afterTurnOf) == [nil])
        #expect(result.text.contains(workspace.name))
        #expect(result.text.contains("branch, notes and chat history were kept"))
    }

    @Test("already archived is an idempotent no-op for both roles")
    func alreadyArchived() async throws {
        let (store, workspace) = try await fixture(state: .archived)
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("an archived workspace reached the app again")
            return .archived
        }
        let identity = BridgeIdentity(
            sessionID: SessionID("s"), workspaceID: workspace.id, role: .workspace
        )
        for (request, identity) in [
            (request(["id": .string(workspace.id.rawValue)]), BridgeIdentity.owner),
            (request([:]), identity),
        ] {
            let result = await tool.call(request, as: identity, store: store)
            #expect(!result.isError)
            #expect(result.text.contains("already archived"))
        }
    }

    @Test("another agent running or waiting refuses the call", arguments: [SessionState.running, .waiting])
    func busySession(_ state: SessionState) async throws {
        let (store, workspace) = try await fixture()
        var busy = Session(workspaceID: workspace.id, title: "Busy")
        busy.state = state
        try await store.upsert(busy)
        let asking = try await store.upsert(Session(workspaceID: workspace.id, title: "Asking"))
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a busy workspace reached the app")
            return .archived
        }
        let identity = BridgeIdentity(
            sessionID: asking.id, workspaceID: workspace.id, role: .workspace
        )
        for (request, identity) in [
            (request(["id": .string(workspace.id.rawValue)]), BridgeIdentity.owner),
            (request([:]), identity),
        ] {
            let result = await tool.call(request, as: identity, store: store)
            #expect(result.isError)
            #expect(result.text.contains("An agent is running"))
        }
    }

    @Test("running setup and queued messages prevent archive", arguments: [true, false])
    func pendingWork(_ setup: Bool) async throws {
        let (store, workspace) = try await fixture()
        if setup {
            var preparing = workspace
            preparing.setupState = .running
            try await store.upsert(preparing)
        } else {
            let session = try await store.upsert(Session(workspaceID: workspace.id, title: "Queued"))
            try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "Work still to do"))
        }
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("pending work reached the archive lifecycle")
            return .archived
        }
        let result = await tool.call(
            request(["id": .string(workspace.id.rawValue)]), as: .owner, store: store
        )
        #expect(result.isError)
        #expect(try await store.workspace(id: workspace.id)?.state == .active)
    }

    @Test("a workspace agent's own queue refuses its own request")
    func ownQueueRefuses() async throws {
        let (store, workspace) = try await fixture()
        var session = Session(workspaceID: workspace.id, title: "Asking")
        session.state = .running
        session = try await store.upsert(session)
        try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "One more thing"))
        let tool = WorkspaceArchiveTool { _ in
            Issue.record("a queued message reached the archive lifecycle")
            return .archived
        }
        let identity = BridgeIdentity(
            sessionID: session.id, workspaceID: workspace.id, role: .workspace
        )
        let result = await tool.call(request([:]), as: identity, store: store)
        #expect(result.isError)
        #expect(result.text.contains("queued messages"))
    }

    @Test("app safety and archive failures reach the caller without a success claim")
    func refusal() async throws {
        let (store, workspace) = try await fixture()
        let tool = WorkspaceArchiveTool { _ in .refused("There are uncommitted changes.") }
        let result = await tool.call(
            request(["id": .string(workspace.id.rawValue)]), as: .owner, store: store
        )
        #expect(result.isError)
        #expect(result.text.contains("uncommitted changes"))
        #expect(try await store.workspace(id: workspace.id)?.state == .active)
    }

    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: "workspace_archive", params: .object(arguments))
    }

    private func fixture(state: WorkspaceState = .active) async throws -> (Store, Workspace) {
        let store = try makeTestStore("archive-tool")
        let repo = try await store.upsert(Repo(name: "Archive tool", path: "/tmp/archive-tool"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Finished review", branch: "review", path: "/tmp/archive-tool-review",
            baseBranch: "main", state: state
        ))
        return (store, workspace)
    }

    private func second(in store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "Other project", path: "/tmp/archive-tool-other"))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "Somebody else's work", branch: "theirs",
            path: "/tmp/archive-tool-theirs", baseBranch: "main"
        ))
    }
}

private actor ArchiveCalls {
    var orders: [WorkspaceArchiveOrder] = []
    func record(_ order: WorkspaceArchiveOrder) { orders.append(order) }
}
