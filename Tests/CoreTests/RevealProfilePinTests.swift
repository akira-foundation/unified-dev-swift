import Foundation
import Testing
@testable import Core

@Suite("Revealing from a chat pinned to another profile", .tags(.persistence), .scratchDirectory)
struct RevealProfilePinTests {
    private final class Revealed: @unchecked Sendable {
        var plans: [RevealPlan] = []

        func tool() -> RevealTool {
            RevealTool { [self] plan in
                plans.append(plan)
                return .revealed(plan.sentence)
            }
        }
    }

    private struct World {
        let store: Store
        let akira: Profile
        let akiraAPI: Repo
        let workspace: Workspace
        let registry = BridgeRegistry()
        let chat = SessionID(rawValue: "ask-chat")

        var identity: BridgeIdentity {
            get throws {
                let token = registry.mintOwner(sessionID: chat)
                return try #require(registry.identity(forToken: token))
            }
        }
    }

    private func world(_ label: String) async throws -> World {
        let store = try makeTestStore(label)
        let akira = try await store.createProfile(name: "Akira", colour: "blue", symbol: "star")
        let akiraAPI = try await store.upsert(Repo(
            name: "api", path: TestScratch.unique("akira-api"), profileID: akira.id
        ))
        let workspace = try await store.upsert(Workspace(
            repoID: akiraAPI.id, name: "Fix the flake", branch: "fix", path: TestScratch.unique("fix"),
            baseBranch: "main"
        ))
        return World(store: store, akira: akira, akiraAPI: akiraAPI, workspace: workspace)
    }

    private func request(_ arguments: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .number(1), method: "reveal", params: .object(arguments))
    }

    @Test("a workspace is refused while the chat is pinned elsewhere, naming its profile and selecting nothing")
    func workspaceRefusedWhilePinnedElsewhere() async throws {
        let world = try await world("reveal-pin-workspace")
        let revealed = Revealed()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(.initial)

        let result = await revealed.tool().call(
            request(["workspace": .string("Fix the flake")]), as: try world.identity, store: world.store
        )

        #expect(result.isError)
        #expect(result.text.contains("Fix the flake"))
        #expect(result.text.contains("Akira"))
        #expect(revealed.plans.isEmpty)
    }

    @Test("Home is refused too while the chat is pinned elsewhere, because it would move the window")
    func homeRefusedWhilePinnedElsewhere() async throws {
        let world = try await world("reveal-pin-home")
        let revealed = Revealed()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(.initial)

        let result = await revealed.tool().call(
            request(["project": .string("api")]), as: try world.identity, store: world.store
        )

        #expect(result.isError)
        #expect(result.text.contains("Akira"))
        #expect(revealed.plans.isEmpty)
    }

    @Test("a refusal never names the profile the owner is looking at")
    func refusalKeepsTheActiveProfileOut() async throws {
        let world = try await world("reveal-pin-silent")
        let debtges = try await world.store.createProfile(name: "Debtges", colour: "red", symbol: "flag")
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(debtges.id)

        let result = await Revealed().tool().call(request([:]), as: try world.identity, store: world.store)

        #expect(result.isError)
        #expect(!result.text.contains("Debtges"))
    }

    @Test("a chat pinned to the active profile reveals as it always did")
    func allowedWhenPinIsActive() async throws {
        let world = try await world("reveal-pin-active")
        let revealed = Revealed()
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(world.akira.id)

        let result = await revealed.tool().call(
            request(["workspace": .string("Fix the flake")]), as: try world.identity, store: world.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(revealed.plans.map(\.target) == [.workspace(world.workspace.id)])
    }

    @Test("a chat with no pin reveals as it always did")
    func allowedWithNoPin() async throws {
        let world = try await world("reveal-no-pin")
        let revealed = Revealed()
        try await world.store.setActiveProfile(world.akira.id)

        let result = await revealed.tool().call(
            request(["workspace": .string("Fix the flake")]), as: try world.identity, store: world.store
        )

        #expect(!result.isError, "\(result.text)")
        #expect(revealed.plans.map(\.target) == [.workspace(world.workspace.id)])
    }

    @Test("a name nothing answers to keeps its own refusal rather than the pinned one")
    func unknownNameKeepsItsRefusal() async throws {
        let world = try await world("reveal-pin-unknown")
        world.registry.pinProfile(world.akira.id, forSession: world.chat)
        try await world.store.setActiveProfile(.initial)

        let result = await Revealed().tool().call(
            request(["workspace": .string("Nothing like it")]), as: try world.identity, store: world.store
        )

        #expect(result.isError)
        #expect(result.text.contains("Nothing like it"))
        #expect(!result.text.contains("another profile"))
    }
}
