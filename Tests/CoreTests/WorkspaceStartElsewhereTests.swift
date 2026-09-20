import Foundation
import Testing
@testable import Core

@Suite("The spawn key when another project is named")
struct WorkspaceStartSpawnKeyTests {
    private let parent = WorkspaceID("w-parent")

    private func order(prompt: String = "Import the webhooks") -> AgentWorkspaceOrder {
        AgentWorkspaceOrder(prompt: prompt)
    }

    @Test("the key of a call that names no project is the one it has always been")
    func unchangedWithoutAProject() {
        #expect(order().spawnID(parentWorkspaceID: parent) == "5d22255bd22601cd")
        #expect(order().spawnID(parentWorkspaceID: parent, otherProject: nil) == "5d22255bd22601cd")
    }

    @Test("the same call to two other projects is two spawns, and neither collides with the owner's key")
    func theProjectIsInTheKey() {
        let app = order().spawnID(parentWorkspaceID: parent, otherProject: RepoID("r-app"))
        let site = order().spawnID(parentWorkspaceID: parent, otherProject: RepoID("r-site"))

        #expect(app != site)
        #expect(app == order().spawnID(parentWorkspaceID: parent, otherProject: RepoID("r-app")))
        #expect(app != order().spawnID(parentWorkspaceID: parent))
        #expect(app != order().spawnID(ownerProject: RepoID("r-app")))
        #expect(app.count == 16)
    }

    @Test("a card's key is its own: stable for one suggestion, different for two with the same prompt")
    func aCardHasItsOwnKey() {
        let one = order().spawnID(suggestion: WorkSuggestionID("s-one"))

        #expect(one == order().spawnID(suggestion: WorkSuggestionID("s-one")))
        #expect(one != order().spawnID(suggestion: WorkSuggestionID("s-two")))
        #expect(one != order().spawnID(parentWorkspaceID: parent))
        #expect(one.count == 16)
    }
}

@Suite("workspace_start in another project", .tags(.persistence), .scratchDirectory)
struct WorkspaceStartElsewhereTests {
    private final class Recorder: @unchecked Sendable {
        var orders: [AgentWorkspaceOrder] = []
        var projects: [Repo] = []
        var origins: [WorkspaceOrigin] = []

        var spawnIDs: [String] { origins.compactMap(\.spawnToolUseID) }

        func tool() -> WorkspaceStartTool {
            WorkspaceStartTool { [self] order, project, _, origin in
                orders.append(order)
                projects.append(project)
                origins.append(origin)
                return StartedWorkspaceSummary(
                    workspaceID: WorkspaceID("w-new-\(orders.count)"),
                    name: order.name ?? "Named by Unified Dev",
                    branch: "claude/named-by-unifieddev",
                    path: "/tmp/worktrees/w-new"
                )
            }
        }
    }

    private struct Fixture {
        let store: Store
        let identity: BridgeIdentity
        let workspace: Workspace
    }

    private func fixture(origin: WorkspaceOrigin = .user, label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "flare", path: "/tmp/flare", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "group occurrences", branch: "claude/group-occurrences",
            path: "/tmp/flare-group", baseBranch: "main", origin: origin
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "First chat"))
        return Fixture(
            store: store,
            identity: BridgeIdentity(sessionID: session.id, workspaceID: workspace.id, role: .workspace),
            workspace: workspace
        )
    }

    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .number(1), method: "workspace_start", params: .object(arguments))
    }

    @Test("a named project from inside a workspace starts it there, and it is still the caller's child")
    func startsInAnotherProject() async throws {
        let f = try await fixture(label: "start-elsewhere")
        let other = try await f.store.upsert(Repo(name: "app", path: "/tmp/app", defaultBranch: "main"))
        let recorder = Recorder()

        let result = await recorder.tool().call(
            request(["prompt": .string("Fix the importer"), "project": .string("app")]),
            as: f.identity, store: f.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(recorder.projects.map(\.id) == [other.id])
        #expect(recorder.origins.first?.parentWorkspaceID == f.workspace.id)
        #expect(
            recorder.spawnIDs == [
                AgentWorkspaceOrder(prompt: "Fix the importer")
                    .spawnID(parentWorkspaceID: f.workspace.id, otherProject: other.id),
            ]
        )
    }

    @Test("a project Unified Dev does not have is refused from inside a workspace, and nothing starts")
    func refusesAnUnknownProject() async throws {
        let f = try await fixture(label: "start-elsewhere-unknown")
        let recorder = Recorder()

        let result = await recorder.tool().call(
            request(["prompt": .string("Fix the importer"), "project": .string("nowhere")]),
            as: f.identity, store: f.store
        )

        #expect(result.isError)
        #expect(result.text.contains("no project called 'nowhere'"))
        #expect(result.text.contains("flare"))
        #expect(recorder.orders.isEmpty)
    }

    @Test("leaving the project out still starts in the caller's own, under the same key as before")
    func omittedProjectIsUnchanged() async throws {
        let f = try await fixture(label: "start-elsewhere-omitted")
        _ = try await f.store.upsert(Repo(name: "app", path: "/tmp/app", defaultBranch: "main"))
        let recorder = Recorder()

        let result = await recorder.tool().call(
            request(["prompt": .string("Fix the importer")]), as: f.identity, store: f.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(recorder.projects.map(\.id) == [f.workspace.repoID])
        #expect(
            recorder.spawnIDs == [
                AgentWorkspaceOrder(prompt: "Fix the importer").spawnID(parentWorkspaceID: f.workspace.id),
            ]
        )
    }

    @Test("naming the caller's own project is the same call as naming none")
    func namingItsOwnProjectIsTheSameCall() async throws {
        let f = try await fixture(label: "start-elsewhere-own")
        let recorder = Recorder()

        _ = await recorder.tool().call(request(["prompt": .string("Fix the importer")]), as: f.identity, store: f.store)
        _ = await recorder.tool().call(
            request(["prompt": .string("Fix the importer"), "project": .string("flare")]),
            as: f.identity, store: f.store
        )

        #expect(recorder.projects.map(\.id) == [f.workspace.repoID, f.workspace.repoID])
        #expect(Set(recorder.spawnIDs).count == 1)
    }

    @Test("a workspace an agent started is refused even when it names another project")
    func noGrandchildrenElsewhere() async throws {
        let f = try await fixture(
            origin: .agent(parentWorkspaceID: WorkspaceID("w-parent"), spawnToolUseID: "t1"),
            label: "start-elsewhere-child"
        )
        _ = try await f.store.upsert(Repo(name: "app", path: "/tmp/app", defaultBranch: "main"))
        let recorder = Recorder()

        let result = await recorder.tool().call(
            request(["prompt": .string("do a thing"), "project": .string("app")]), as: f.identity, store: f.store
        )

        #expect(result.isError)
        #expect(result.text.contains("itself started by an agent"))
        #expect(recorder.orders.isEmpty)
    }

    @Test("children running in another project count against the caller's ceiling")
    func childrenElsewhereCount() async throws {
        let f = try await fixture(label: "start-elsewhere-limit")
        let other = try await f.store.upsert(Repo(name: "app", path: "/tmp/app", defaultBranch: "main"))
        for index in 0..<WorkspaceStartAllowance.maximumChildren {
            _ = try await f.store.upsert(Workspace(
                repoID: other.id, name: "child \(index)", branch: "claude/child-\(index)",
                path: "/tmp/elsewhere-\(index)", baseBranch: "main",
                origin: .agent(parentWorkspaceID: f.workspace.id, spawnToolUseID: "t\(index)")
            ))
        }
        let recorder = Recorder()

        let result = await recorder.tool().call(request(["prompt": .string("one more")]), as: f.identity, store: f.store)

        #expect(result.isError)
        #expect(recorder.orders.isEmpty)
    }
}
