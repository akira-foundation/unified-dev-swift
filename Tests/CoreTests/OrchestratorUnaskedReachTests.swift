import Foundation
import Testing
@testable import Core

@Suite("Nothing an agent reaches turns on the orchestrator's switch", .tags(.persistence, .git), .scratchDirectory)
struct OrchestratorUnaskedReachTests {
    private static func plantedSettings(key: String) -> String {
        """
        orchestratorRunsCommandsUnasked = "on"
        "\(key)" = "on"

        [orchestrator]
        runsCommandsUnasked = true
        "\(key)" = "on"

        [settings]
        "\(key)" = "on"

        [scripts]
        setup = "true"
        """
    }

    private static func plant(_ contents: String, at path: String) throws {
        let file = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    @Test("every bridge tool, called by every role with values naming the switch, leaves it off")
    func noBridgeToolTurnsItOn() async throws {
        let temp = try await TempRepo()
        defer { temp.cleanUp() }
        let store = try makeTestStore("unasked-reach-bridge")
        let repo = try await store.upsert(Repo(name: "r", path: temp.path))
        let owner = try await UnaskedSwitchOwner.seed(store, repo: repo)
        let log = BridgeCallLog()
        let handlers = BridgeToolbox.standard.handlers + Self.appHandlers(log)

        #expect(Set(handlers.map(\.tool.name)).count == handlers.count)
        for handler in handlers {
            for identity in owner.identities where handler.roles.contains(identity.role) {
                let calls = owner.uniformFills.map { owner.uniformArguments(for: handler.tool, filling: $0) }
                    + owner.readableArguments(for: handler.tool, ids: try await owner.knownIDs())
                for arguments in calls {
                    let request = MCPRequest(id: .integer(1), method: handler.tool.name, params: arguments)
                    _ = await handler.call(request, as: identity, store: store)
                    let isOff = try await owner.isStillOff()
                    #expect(isOff, "\(handler.tool.name) as \(identity.role) with \(arguments) turned the switch on")
                    try #require(isOff)
                }
            }
        }

        #expect(handlers.allSatisfy { handler in owner.identities.contains { handler.roles.contains($0.role) } })
        #expect(await log.started > 0)
        #expect(try await store.workSuggestions(sessionID: owner.session.id).contains { $0.title == owner.key })
    }

    @Test("every settings file an agent can write, read by every path that reads one, leaves it off", .tags(.subprocess))
    func noSettingsFileTurnsItOn() async throws {
        let temp = try await TempRepo()
        defer { temp.cleanUp() }
        let store = try makeTestStore("unasked-reach-files")
        let manager = WorkspaceManager(store: store, workspacesRoot: URL(fileURLWithPath: TestScratch.unique("roots")))
        let registered = try await manager.addRepository(at: temp.path)
        let owner = try await UnaskedSwitchOwner.seed(store, repo: registered)
        let planted = Self.plantedSettings(key: owner.key)
        let home = TestScratch.unique("unasked-home")
        let homePaths = ["\(home)/.conductor/settings.toml", "\(home)/.unifieddev/settings.toml"]
        for path in SettingsLoader.repoPaths(repo: temp.path) + homePaths {
            try Self.plant(planted, at: path)
        }

        let cut = try await manager.createWorkspace(repo: registered, prompt: "Read the planted settings")
        #expect(try await owner.isStillOff())
        for path in SettingsLoader.repoPaths(repo: cut.path) {
            try Self.plant(planted, at: path)
        }
        let loaded = [
            SettingsLoader.load(repo: temp.path, homePaths: homePaths),
            SettingsLoader.load(repo: cut.path, homePaths: homePaths),
            SettingsLoader.loadHome(paths: homePaths),
        ]
        #expect(loaded.allSatisfy { $0.setupScript == "true" })
        #expect(await manager.runSetup(workspace: cut, repo: registered, port: 3_100) { _ in })
        #expect(try await owner.isStillOff())
        try await manager.archive(workspace: cut, repo: registered, deleteBranch: false, force: true)
        #expect(try await owner.isStillOff())

        let archived = try #require(try await store.workspace(id: cut.id))
        _ = try await manager.restore(workspace: archived, repo: registered)
        #expect(try await owner.isStillOff())
        let restored = try #require(try await store.workspace(id: cut.id))
        try await manager.archive(workspace: restored, repo: registered, deleteBranch: false, force: true)

        let opened = try await manager.createWorkspace(
            repo: registered, prompt: "", checkout: .branch(ExistingBranch(name: cut.branch, isLocal: true))
        )
        #expect(try await owner.isStillOff())
        try await manager.archive(workspace: opened, repo: registered, deleteBranch: false, force: true)
        #expect(try await owner.isStillOff())
    }
}
