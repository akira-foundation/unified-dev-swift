import Foundation
import Testing
@testable import Core

@Suite("The bridge sees only the caller's profile", .tags(.persistence), .scratchDirectory)
struct BridgeProfileScopeTests {
    private func listed(_ result: BridgeToolResult) -> Bool {
        result.text.contains(ProfileScopeWorld.farProjectName)
    }

    @Test("project_list from a workspace lists only its profile")
    func listFromWorkspace() async throws {
        let world = try await ProfileScopeWorld.make("scope-list-workspace")
        let request = world.request("project_list")

        let home = await ProjectListTool().call(request, as: world.homeAgent, store: world.store)
        #expect(home.text.contains("home-project"))
        #expect(!listed(home))

        let far = await ProjectListTool().call(request, as: world.farAgent, store: world.store)
        #expect(listed(far))
        #expect(!far.text.contains("home-project"))

        try await world.store.setActiveProfile(world.akira)
        let unmoved = await ProjectListTool().call(request, as: world.homeAgent, store: world.store)
        #expect(unmoved.text.contains("home-project"))
        #expect(!listed(unmoved))
    }

    @Test("project_list from the owner lists the active profile")
    func listFromOwner() async throws {
        let world = try await ProfileScopeWorld.make("scope-list-owner")
        let request = world.request("project_list")
        let ask = BridgeIdentity(ownerSession: .new())

        for identity in [BridgeIdentity.owner, ask] {
            try await world.store.setActiveProfile(.initial)
            let initial = await ProjectListTool().call(request, as: identity, store: world.store)
            #expect(initial.text.contains("home-project"))
            #expect(!listed(initial))

            try await world.store.setActiveProfile(world.akira)
            let active = await ProjectListTool().call(request, as: identity, store: world.store)
            #expect(listed(active))
            #expect(!active.text.contains("home-project"))
        }
    }

    @Test("an orchestrator is limited to its profile like any other workspace")
    func orchestrator() async throws {
        let world = try await ProfileScopeWorld.make("scope-orchestrator")
        try await world.store.update(workspaceID: world.homeWorkspace.id) { $0.isOrchestrator = true }

        let projects = await ProjectListTool().call(
            world.request("project_list"), as: world.homeAgent, store: world.store
        )
        #expect(!listed(projects))
        await world.expectSameAsInvented { given in
            await ChatListTool().call(
                world.request("chat_list", ["workspace": .string(given)]), as: world.homeAgent, store: world.store
            )
        }
    }

    @Test("a workspace in another profile is unknown, and its name is not leaked")
    func unknownAcrossProfiles() async throws {
        let world = try await ProfileScopeWorld.make("scope-unknown")
        let say = WorkspaceSayTool { _ in .refused("delivered") }

        for identity in [world.homeAgent, BridgeIdentity.owner] {
            await world.expectSameAsInvented { given in
                await say.call(
                    world.request("workspace_say", ["workspace": .string(given), "message": .string("Hello")]),
                    as: identity, store: world.store
                )
            }
            await world.expectSameAsInvented { given in
                await ChatReadTool().call(
                    world.request("chat_read", [
                        "chat": .string(ProfileScopeWorld.farChat), "workspace": .string(given),
                    ]),
                    as: identity, store: world.store
                )
            }
            await world.expectSameAsInvented { given in
                await ChatListTool().call(
                    world.request("chat_list", ["workspace": .string(given)]), as: identity, store: world.store
                )
            }
            await world.expectSameAsInvented { given in
                await WorkspaceDiffTool().call(
                    world.request("workspace_diff", ["workspace": .string(given)]), as: identity, store: world.store
                )
            }
        }
    }

    @Test("the archived branch of a target in another profile does not reveal its name")
    func archivedAcrossProfiles() async throws {
        let world = try await ProfileScopeWorld.make("scope-archived")
        try await world.store.update(workspaceID: world.farWorkspace.id) { $0.archive() }

        await world.expectSameAsInvented { given in
            await WorkspaceSayTool { _ in .refused("delivered") }.call(
                world.request("workspace_say", ["workspace": .string(given), "message": .string("Hello")]),
                as: world.homeAgent, store: world.store
            )
        }
        await world.expectSameAsInvented { given in
            await ChatListTool().call(
                world.request("chat_list", ["workspace": .string(given)]), as: world.homeAgent, store: world.store
            )
        }
    }

    @Test("a workspace identity whose row is gone sees nothing")
    func goneIdentity() async throws {
        let world = try await ProfileScopeWorld.make("scope-gone")
        let gone = BridgeIdentity(sessionID: .new(), workspaceID: .new(), role: .workspace)

        let projects = await ProjectListTool().call(world.request("project_list"), as: gone, store: world.store)
        #expect(!projects.text.contains("home-project"))
        #expect(!listed(projects))

        let named = await ChatListTool().call(
            world.request("chat_list", ["workspace": .string(world.homeWorkspace.id.rawValue)]),
            as: gone, store: world.store
        )
        #expect(named.isError)
        #expect(!named.text.contains("Home Workspace"))
        #expect(named.text.contains("nothing"))
    }

    @Test("inside its own profile a caller still reaches another workspace")
    func withinProfile() async throws {
        let world = try await ProfileScopeWorld.make("scope-within")
        let sibling = try await world.store.upsert(Workspace(
            repoID: world.farProject.id, name: "Sibling", branch: "sibling",
            path: TestScratch.unique("sibling"), baseBranch: "main"
        ))
        let request = world.request("chat_list", ["workspace": .string(sibling.id.rawValue)])

        let fromAgent = await ChatListTool().call(request, as: world.farAgent, store: world.store)
        #expect(!fromAgent.isError)

        try await world.store.setActiveProfile(world.akira)
        let fromOwner = await ChatListTool().call(request, as: .owner, store: world.store)
        #expect(!fromOwner.isError)

        let say = await WorkspaceSayTool { _ in .refused("delivered") }.call(
            world.request("workspace_say", ["workspace": .string(sibling.id.rawValue), "message": .string("Hello")]),
            as: world.farAgent, store: world.store
        )
        #expect(say.text.contains("delivered"))
    }

    @Test("project_list in an empty profile does not say Unified Dev is empty")
    func emptyProfile() async throws {
        let world = try await ProfileScopeWorld.make("scope-empty")
        let empty = try await world.store.createProfile(name: "Empty", colour: "red", symbol: "circle")
        try await world.store.setActiveProfile(empty.id)

        let result = await ProjectListTool().call(world.request("project_list"), as: .owner, store: world.store)
        #expect(!result.isError)
        #expect(!result.text.contains("home-project"))
        #expect(result.text.contains("This profile has no projects yet"))
    }
}

@Suite("project_add and the caller's profile", .tags(.persistence, .subprocess), .scratchDirectory)
struct BridgeProfileScopeAddTests {
    private func add(_ path: String) -> MCPRequest {
        MCPRequest(id: .number(1), method: "project_add", params: .object(["path": .string(path)]))
    }

    @Test("project_add files the project under the caller's profile")
    func filesUnderCaller() async throws {
        let store = try makeTestStore("scope-add")
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        try await store.setActiveProfile(akira.id)
        let repo = try await TempRepo()

        let result = await ProjectAddTool().call(add(repo.path), as: .owner, store: store)

        #expect(!result.isError)
        let projects = try await store.repos()
        #expect(projects.map(\.profileID) == [akira.id])
    }

    @Test("a project registered under another profile cannot be added")
    func refusesAnotherProfile() async throws {
        let store = try makeTestStore("scope-add-elsewhere")
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        try await store.setActiveProfile(akira.id)
        let repo = try await TempRepo()
        _ = await ProjectAddTool().call(add(repo.path), as: .owner, store: store)
        let registered = try #require(try await store.repos().first)
        try await store.setActiveProfile(.initial)

        let result = await ProjectAddTool().call(add(repo.path), as: .owner, store: store)

        #expect(result.isError)
        #expect(result.text.contains("another profile"))
        #expect(!result.text.contains("Akira"))
        #expect(!result.text.contains(registered.id.rawValue))
        #expect(!result.text.contains("default_branch"))
        #expect(try await store.repo(id: registered.id)?.profileID == akira.id)
    }

    @Test("a suggestion's folder is filed under the profile it is given")
    func admitFiles() async throws {
        let store = try makeTestStore("scope-admit")
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: store)

        let admitted = await WorkSuggestionLaunch.admit(repo.path, profileID: akira.id, with: manager)

        #expect(try admitted.get().profileID == akira.id)
    }

    @Test("a suggestion's folder registered under another profile is refused")
    func admitRefuses() async throws {
        let store = try makeTestStore("scope-admit-elsewhere")
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: store)
        _ = await WorkSuggestionLaunch.admit(repo.path, profileID: akira.id, with: manager)

        let admitted = await WorkSuggestionLaunch.admit(repo.path, profileID: .initial, with: manager)

        guard case .failure(let refusal) = admitted else {
            Issue.record("expected a refusal, got \(admitted)")
            return
        }
        #expect(refusal.sentence.contains("another profile"))
        #expect(!refusal.sentence.contains("Akira"))
    }

    @Test("adding a project already in the caller's profile still changes nothing")
    func sameProfileAgain() async throws {
        let store = try makeTestStore("scope-add-twice")
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        try await store.setActiveProfile(akira.id)
        let repo = try await TempRepo()
        _ = await ProjectAddTool().call(add(repo.path), as: .owner, store: store)

        let result = await ProjectAddTool().call(add(repo.path), as: .owner, store: store)

        #expect(!result.isError)
        #expect(result.text.contains("already_a_project"))
    }
}
