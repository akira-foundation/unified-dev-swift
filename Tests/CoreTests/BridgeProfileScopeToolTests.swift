import Foundation
import Testing
@testable import Core

@Suite("Each owner tool stays inside the active profile", .tags(.persistence), .scratchDirectory)
struct BridgeProfileScopeToolTests {
    @Test("workspace_list lists the active profile and cannot name another")
    func workspaceList() async throws {
        let world = try await ProfileScopeWorld.make("scope-workspace-list")

        let all = await WorkspaceListTool().call(
            world.request("workspace_list", ["include_archived": .bool(true)]), as: .owner, store: world.store
        )
        #expect(all.text.contains("Home Workspace"))
        #expect(!all.text.contains(ProfileScopeWorld.farWorkspaceName))

        let named = await WorkspaceListTool().call(
            world.request("workspace_list", ["project": .string(ProfileScopeWorld.farProjectName)]),
            as: .owner, store: world.store
        )
        #expect(named.isError)
        #expect(!named.text.contains(ProfileScopeWorld.farWorkspaceName))
    }

    @Test("whoami from the owner counts the active profile")
    func whoami() async throws {
        let world = try await ProfileScopeWorld.make("scope-whoami")
        _ = try await world.store.upsert(Workspace(
            repoID: world.farProject.id, name: "Second", branch: "second",
            path: TestScratch.unique("second"), baseBranch: "main"
        ))

        let answer = await WhoamiTool().call(world.request("whoami"), as: .owner, store: world.store)

        #expect(answer.text.contains("\"projects\" : 1"))
        #expect(answer.text.contains("\"workspaces\" : 1"))
    }

    @Test("reveal cannot name a workspace or a project in another profile")
    func reveal() async throws {
        let world = try await ProfileScopeWorld.make("scope-reveal")
        let tool = RevealTool { plan in .revealed(plan.sentence) }

        let workspace = await tool.call(
            world.request("reveal", ["workspace": .string(ProfileScopeWorld.farWorkspaceName)]),
            as: .owner, store: world.store
        )
        #expect(workspace.isError)
        #expect(workspace.text.contains("Home Workspace"))

        let project = await tool.call(
            world.request("reveal", ["project": .string(ProfileScopeWorld.farProjectName)]),
            as: .owner, store: world.store
        )
        #expect(project.isError)
        #expect(project.text.contains("home-project"))
    }

    @Test("project_hide leaves a project in another profile alone")
    func hide() async throws {
        let world = try await ProfileScopeWorld.make("scope-hide")

        let result = await ProjectHideTool().call(
            world.request("project_hide", ["project": .string(ProfileScopeWorld.farProjectName)]),
            as: .owner, store: world.store
        )

        #expect(result.isError)
        #expect(try await world.store.repo(id: world.farProject.id)?.hidden == false)
    }

    @Test("workspace_start refuses a project in another profile and does not list it")
    func start() async throws {
        let world = try await ProfileScopeWorld.make("scope-start")
        let tool = WorkspaceStartTool(start: { _, _, _, _ in throw WorkspaceError.notARepository("never reached") })

        for identity in [world.homeAgent, BridgeIdentity.owner] {
            let result = await tool.call(
                world.request("workspace_start", [
                    "prompt": .string("Do it"), "project": .string(world.farProject.path),
                ]),
                as: identity, store: world.store
            )
            #expect(result.isError)
            #expect(result.text.contains("has no project called"))
            #expect(!result.text.contains(ProfileScopeWorld.farProjectName))
        }
    }

    @Test("work_suggest treats a project in another profile as one it does not have")
    func suggest() async throws {
        let world = try await ProfileScopeWorld.make("scope-suggest")
        func suggesting(_ project: String) -> MCPRequest {
            world.request("work_suggest", [
                "title": .string("A title"), "why": .string("A reason"),
                "prompt": .string("A prompt"), "project": .string(project),
            ])
        }

        let byName = await WorkSuggestTool().call(
            suggesting(ProfileScopeWorld.farProjectName), as: world.homeAgent, store: world.store
        )
        #expect(byName.isError)
        #expect(byName.text.contains("home-project"))

        func place(_ path: String) async throws -> [String] {
            let answer = await WorkSuggestTool().call(suggesting(path), as: world.homeAgent, store: world.store)
            #expect(!answer.isError, "\(answer.text)")
            let fields = try #require(
                try JSONSerialization.jsonObject(with: Data(answer.text.utf8)) as? [String: Any]
            )
            return ["state", "where", "note"].map { key in
                (fields[key] as? String ?? "").replacingOccurrences(of: path, with: "<path>")
            }
        }
        let registered = try await place(world.farProject.path)
        let unregistered = try await place(TestScratch.unique("nowhere"))
        #expect(registered == unregistered)
    }

    @Test("workspace_rename from the owner cannot reach another profile")
    func renameOwner() async throws {
        let world = try await ProfileScopeWorld.make("scope-rename")

        await world.expectSameAsInvented { given in
            await WorkspaceRenameTool().call(
                world.request("workspace_rename", ["workspace": .string(given), "name": .string("New")]),
                as: .owner, store: world.store
            )
        }
        #expect(try await world.store.workspace(id: world.farWorkspace.id)?.name == ProfileScopeWorld.farWorkspaceName)
    }

    @Test("workspace_archive from the owner cannot reach another profile")
    func archiveOwner() async throws {
        let world = try await ProfileScopeWorld.make("scope-archive")
        let tool = WorkspaceArchiveTool { _ in .archived }

        let real = await tool.call(
            world.request("workspace_archive", ["id": .string(world.farWorkspace.id.rawValue)]),
            as: .owner, store: world.store
        )
        let invented = await tool.call(
            world.request("workspace_archive", ["id": .string("no-such-id")]), as: .owner, store: world.store
        )

        #expect(real.isError)
        #expect(real.text == invented.text)
    }

    @Test("a workspace started in a project since moved away is out of reach of who started it")
    func startedThenMoved() async throws {
        let world = try await ProfileScopeWorld.make("scope-moved")
        let handedOver = try await world.store.upsert(Repo(name: "handed-over", path: TestScratch.unique("handed")))
        let started = try await world.store.upsert(Workspace(
            repoID: handedOver.id, name: "Started", branch: "started",
            path: TestScratch.unique("started"), baseBranch: "main",
            origin: .agent(parentWorkspaceID: world.homeWorkspace.id, spawnToolUseID: "spawn")
        ))
        try await world.store.move(repoID: handedOver.id, to: world.akira)

        let archive = await WorkspaceArchiveTool { _ in .archived }.call(
            world.request("workspace_archive", ["id": .string(started.id.rawValue)]),
            as: world.homeAgent, store: world.store
        )
        #expect(archive.isError)

        let rename = await WorkspaceRenameTool().call(
            world.request("workspace_rename", ["workspace": .string(started.id.rawValue), "name": .string("New")]),
            as: world.homeAgent, store: world.store
        )
        #expect(rename.isError)
        #expect(try await world.store.workspace(id: started.id)?.name == "Started")
    }

    @Test("workspace_merge from the owner cannot reach another profile, not even as an alias")
    func merge() async throws {
        let world = try await ProfileScopeWorld.make("scope-merge")
        let tool = WorkspaceMergeTool(read: { _ in .noPullRequest }) { _, _, _ in .turnBegun(chat: "Merge") }

        await world.expectSameAsInvented { given in
            await tool.call(
                world.request("workspace_merge", ["workspace": .string(given)]), as: .owner, store: world.store
            )
        }
    }
}
