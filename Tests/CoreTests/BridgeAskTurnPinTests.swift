import Foundation
import Testing
@testable import Core

@Suite("An Ask chat keeps the profile its turn began in", .tags(.persistence), .scratchDirectory)
struct BridgeAskTurnPinTests {
    private final class StartedIn: @unchecked Sendable {
        var projects: [Repo] = []

        func tool() -> WorkspaceStartTool {
            WorkspaceStartTool { [self] _, project, _, _ in
                projects.append(project)
                return StartedWorkspaceSummary(
                    workspaceID: WorkspaceID(rawValue: "w-new"), name: "New", branch: "new", path: "/tmp/w-new"
                )
            }
        }
    }

    private struct World {
        let store: Store
        let akira: Profile
        let unifiedAPI: Repo
        let akiraAPI: Repo
        let registry = BridgeRegistry()
        let chat = SessionID(rawValue: "ask-chat")

        var identity: BridgeIdentity {
            get throws {
                let token = registry.mintOwner(sessionID: chat)
                return try #require(registry.identity(forToken: token))
            }
        }

        func startRequest() -> MCPRequest {
            MCPRequest(id: .number(1), method: "workspace_start", params: .object([
                "prompt": .string("Do it"), "project": .string("api"),
            ]))
        }
    }

    private func world(_ label: String) async throws -> World {
        let store = try makeTestStore(label)
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        let unifiedAPI = try await store.upsert(Repo(name: "api", path: TestScratch.unique("unified-api")))
        let akiraAPI = try await store.upsert(Repo(
            name: "api", path: TestScratch.unique("akira-api"), profileID: akira.id
        ))
        return World(store: store, akira: akira, unifiedAPI: unifiedAPI, akiraAPI: akiraAPI)
    }

    private func answer(_ result: BridgeToolResult) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(result.text.utf8)) as? [String: Any])
    }

    @Test("workspace_start lands in the pinned profile after the owner switches, and says so")
    func startStaysInPinnedProfile() async throws {
        let world = try await world("pin-start")
        let startedIn = StartedIn()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(.initial)

        let result = await startedIn.tool().call(world.startRequest(), as: try world.identity, store: world.store)

        #expect(!result.isError, "\(result.text)")
        #expect(startedIn.projects.map(\.id) == [world.akiraAPI.id])
        #expect(try answer(result)["profile"] as? String == "Akira")
    }

    @Test("a new turn takes the profile active when it starts")
    func newTurnTakesNewActive() async throws {
        let world = try await world("pin-new-turn")
        let startedIn = StartedIn()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        world.registry.releaseProfilePin(forSession: world.chat)
        world.registry.pinProfile(.initial, forSession: world.chat)
        try await world.store.setActiveProfile(world.akira.id)

        let result = await startedIn.tool().call(world.startRequest(), as: try world.identity, store: world.store)

        #expect(startedIn.projects.map(\.id) == [world.unifiedAPI.id])
        #expect(try answer(result)["profile"] as? String == "Unified")
    }

    @Test("a chat between turns and the standalone owner both follow the active profile")
    func unpinnedFollowsActive() async throws {
        let world = try await world("pin-none")
        try await world.store.setActiveProfile(world.akira.id)
        world.registry.pinProfile(.initial, forSession: world.chat)
        world.registry.releaseProfilePin(forSession: world.chat)

        let chat = try await BridgeProfileScope.profile(of: try world.identity, store: world.store)
        let standalone = try await BridgeProfileScope.profile(of: .owner, store: world.store)

        #expect(chat == world.akira.id)
        #expect(standalone == world.akira.id)
    }

    @Test("a pin only reaches the chat it names")
    func pinIsPerChat() async throws {
        let world = try await world("pin-other-chat")
        let other = SessionID(rawValue: "other-chat")
        try await world.store.setActiveProfile(world.akira.id)
        world.registry.pinProfile(.initial, forSession: world.chat)
        let token = world.registry.mintOwner(sessionID: other)
        world.registry.admit(ownerToken: "standalone")

        #expect(world.registry.identity(forToken: "standalone")?.pinnedProfile == nil)
        #expect(world.registry.identity(forToken: token)?.pinnedProfile == nil)
        #expect(try world.identity.pinnedProfile == .initial)
    }

    @Test("a pin survives the chat being given a new token, and goes when it retires")
    func pinLifetime() async throws {
        let world = try await world("pin-life")
        world.registry.pinProfile(world.akira.id, forSession: world.chat)

        #expect(try world.identity.pinnedProfile == world.akira.id)

        world.registry.retire(sessionID: world.chat)

        #expect(try world.identity.pinnedProfile == nil)
    }

    @Test("a pinned profile deleted during the turn leaves an empty scope")
    func deletedPinIsEmpty() async throws {
        let world = try await world("pin-deleted")
        let gone = try await world.store.createProfile(name: "Gone", colour: "red", symbol: "star")
        world.registry.pinProfile(gone.id, forSession: world.chat)
        try await world.store.deleteProfile(id: gone.id)

        let scope = try await BridgeProfileScope.profile(of: try world.identity, store: world.store)
        let repos = try await BridgeProfileScope.repos(for: try world.identity, store: world.store)

        #expect(scope == nil)
        #expect(repos.isEmpty)
    }

    @Test("a workspace caller is named its own profile too")
    func workspaceCallerSeesProfile() async throws {
        let world = try await world("pin-agent")
        let startedIn = StartedIn()
        let workspace = try await world.store.upsert(Workspace(
            repoID: world.akiraAPI.id, name: "Caller", branch: "caller",
            path: TestScratch.unique("caller"), baseBranch: "main"
        ))
        let session = try await world.store.upsert(Session(workspaceID: workspace.id, title: "Caller"))
        let caller = BridgeIdentity(sessionID: session.id, workspaceID: workspace.id, role: .workspace)

        let result = await startedIn.tool().call(world.startRequest(), as: caller, store: world.store)

        #expect(try answer(result)["profile"] as? String == "Akira")
    }

    @Test("project_add names the profile it landed in", .tags(.subprocess))
    func projectAddNamesProfile() async throws {
        let world = try await world("pin-add")
        let repo = try await TempRepo()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)

        let result = await ProjectAddTool().call(
            MCPRequest(id: .number(1), method: "project_add", params: .object(["path": .string(repo.path)])),
            as: try world.identity,
            store: world.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(try answer(result)["profile"] as? String == "Akira")
        let addedPath = try #require(try answer(result)["path"] as? String)
        let added = try await world.store.repo(path: addedPath)
        #expect(added?.profileID == world.akira.id)
    }
}
