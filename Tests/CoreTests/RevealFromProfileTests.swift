import Testing
@testable import Core

@Suite("Revealing from a profile the window is not showing", .tags(.persistence), .scratchDirectory)
struct RevealFromProfileTests {
    private actor Reveals {
        private(set) var plans: [RevealPlan] = []
        func record(_ plan: RevealPlan) { plans.append(plan) }
    }

    private func tool(recording reveals: Reveals) -> RevealTool {
        RevealTool { plan in
            await reveals.record(plan)
            return .revealed(plan.sentence)
        }
    }

    @Test("a workspace caller in a hidden profile is refused and nothing is selected")
    func hiddenProfileRefused() async throws {
        let world = try await ProfileScopeWorld.make("reveal-hidden")
        let reveals = Reveals()

        for arguments: [String: JSONValue] in [
            ["workspace": .string(ProfileScopeWorld.farWorkspaceName)],
            ["project": .string(ProfileScopeWorld.farProjectName)],
            [:],
        ] {
            let answer = await tool(recording: reveals).call(
                world.request("reveal", arguments), as: world.farAgent, store: world.store
            )
            #expect(answer.isError)
            #expect(answer.text == BridgeProfileScope.windowShowsAnotherProfile)
        }

        #expect(await reveals.plans.isEmpty)
    }

    @Test("a workspace caller in the active profile moves the window")
    func activeProfileAllowed() async throws {
        let world = try await ProfileScopeWorld.make("reveal-active")
        try await world.store.setActiveProfile(world.akira)
        let reveals = Reveals()

        let answer = await tool(recording: reveals).call(
            world.request("reveal", ["workspace": .string(ProfileScopeWorld.farWorkspaceName)]),
            as: world.farAgent, store: world.store
        )

        #expect(!answer.isError, "\(answer.text)")
        #expect(await reveals.plans.map(\.target) == [.workspace(world.farWorkspace.id)])
    }

    @Test("the owner reveals inside the active profile")
    func ownerAllowed() async throws {
        let world = try await ProfileScopeWorld.make("reveal-owner")
        let reveals = Reveals()

        let answer = await tool(recording: reveals).call(
            world.request("reveal", ["workspace": .string(world.homeWorkspace.name)]),
            as: .owner, store: world.store
        )

        #expect(!answer.isError, "\(answer.text)")
        #expect(await reveals.plans.map(\.target) == [.workspace(world.homeWorkspace.id)])
    }

    @Test("a caller whose workspace can no longer be read is refused")
    func unreadableCallerRefused() async throws {
        let world = try await ProfileScopeWorld.make("reveal-gone")
        let reveals = Reveals()
        let gone = BridgeIdentity(sessionID: .new(), workspaceID: .new(), role: .workspace)

        let answer = await tool(recording: reveals).call(world.request("reveal"), as: gone, store: world.store)

        #expect(answer.isError)
        #expect(await reveals.plans.isEmpty)
    }

    @Test("the refusal names no project, workspace or profile")
    func refusalLeaksNothing() {
        let sentence = BridgeProfileScope.windowShowsAnotherProfile

        #expect(!sentence.contains(ProfileScopeWorld.farProjectName))
        #expect(!sentence.contains(ProfileScopeWorld.farWorkspaceName))
        #expect(!sentence.contains("Akira"))
    }

    @Test("the toolbox offers reveal to the owner alone, so the refusal is a second line")
    func offeredToTheOwnerAlone() {
        #expect(RevealTool { plan in .revealed(plan.sentence) }.roles == [.owner])
    }
}
