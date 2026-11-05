import Foundation
import Testing
@testable import Core

@Suite("Nothing an agent reaches turns on the orchestrator's switch", .tags(.persistence, .git), .scratchDirectory)
struct OrchestratorUnaskedReachTests {
    private struct NotStarted: Error {}

    static let appHandlers: [any BridgeToolHandling] = [
        WorkspaceStartTool(start: { _, _, _, _ in throw NotStarted() }, resolvePullRequest: { _, _ in .failure("") }),
        PaneOpenTool { _, _ in .opened("") },
        TerminalStartTool { _, _ in .opened("") },
        TerminalReadTool { _, _ in .refused("") },
        TerminalWriteTool { _, _ in .refused("") },
        TerminalSendKeyTool { _, _ in .refused("") },
        MediaShowTool { _, _ in .refused("") },
        CanvasShowTool { _, _ in .refused("") },
        PaneSplitTool { _, _, _, _ in .opened("") },
        PaneCloseTool { _, _ in .opened("") },
        PaneRenameTool { _, _, _ in .opened("") },
        PaneListTool { _ in nil },
        WorkspaceTabsTool { _ in nil },
        WorkspaceTabSelectTool { _, _ in .refused("") },
        BrowserReadTool { _, _ in .refused("") },
        BrowserReloadTool { _, _ in .refused("") },
        BrowserGoTool { _, _ in .refused("") },
        BrowserScrollTool { _, _ in .refused("") },
        BrowserScreenshotTool { _, _ in .refused("") },
        BrowserTextTool { _, _ in .refused("") },
        BrowserPageOutlineTool { _, _ in .refused("") },
        BrowserClickTool { _, _ in .refused("") },
        BrowserFillTool { _, _ in .refused("") },
        BrowserPressTool { _, _ in .refused("") },
        BrowserWaitTool { _, _ in .refused("") },
        WorkspaceArchiveTool { _ in .refused("") },
        WorkspaceMergeTool(read: { _ in .noPullRequest }) { _, _, _ in .refused("") },
        RevealTool { _ in .refused("") },
        AgentStartTool { _, _, _ in .refused("") },
        AgentSayTool { _, _, _, _ in .refused("") },
        AgentStopTool { _, _, _ in .refused("") },
        WorkspaceSayTool { _ in .refused("") },
    ]

    private struct Orchestrator {
        let repo: Repo
        let lead: Workspace
        let session: Session
        let grants: SessionGrants
        let store: Store

        var key: String { OrchestratorUnaskedCommands.key(repoID: repo.id) }

        func isStillOff() async throws -> Bool {
            let stored = try await store.setting(key)
            let isOn = await OrchestratorUnaskedCommands.isOn(repoID: repo.id, in: store)
            let answers = await grants.answersItself(
                toolName: "Bash", input: .object(["command": .string("make build && make test")])
            )
            return stored == nil && !isOn && !answers
        }
    }

    private func seedOrchestrator(_ store: Store, repo: Repo) async throws -> Orchestrator {
        let lead = try await store.upsert(Workspace(
            repoID: repo.id, name: "lead", branch: "b/lead", path: TestScratch.unique("lead"), baseBranch: "main"
        ))
        _ = try await store.setOrchestrator(true, workspaceID: lead.id)
        let session = try await store.upsert(Session(workspaceID: lead.id, title: "Chat"))
        return Orchestrator(
            repo: repo, lead: lead, session: session,
            grants: SessionGrants(store: store, workspaceID: lead.id), store: store
        )
    }

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

    private static func fills(for orchestrator: Orchestrator) -> [JSONValue] {
        [
            .string(orchestrator.key), .string("on"), .string(orchestrator.lead.id.rawValue),
            .string(orchestrator.repo.path), .bool(true), .integer(1),
        ]
    }

    private static func arguments(for tool: BridgeTool, filling value: JSONValue, key: String) -> JSONValue {
        var arguments: [String: JSONValue] = [
            "key": .string(key), "value": .string("on"), "setting": .string(key), "enabled": .bool(true),
        ]
        guard case .object(let schema) = tool.inputSchema,
              case .object(let properties)? = schema["properties"] else { return .object(arguments) }
        for (name, property) in properties {
            guard case .object(let shape) = property, case .string(let type)? = shape["type"] else {
                arguments[name] = value
                continue
            }
            arguments[name] = Self.shaped(value, as: type)
        }
        return .object(arguments)
    }

    private static func shaped(_ value: JSONValue, as type: String) -> JSONValue {
        switch type {
        case "array": .array([value])
        case "object": .object(["key": value, "value": .string("on")])
        default: value
        }
    }

    @Test("every bridge tool, called by every role with values naming the switch, leaves it off")
    func noBridgeToolTurnsItOn() async throws {
        let store = try makeTestStore("unasked-reach-bridge")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("r")))
        let orchestrator = try await seedOrchestrator(store, repo: repo)
        let handlers = BridgeToolbox.standard.handlers + Self.appHandlers
        let identities = [
            BridgeIdentity(sessionID: orchestrator.session.id, workspaceID: orchestrator.lead.id, role: .workspace),
            BridgeIdentity(ownerSession: orchestrator.session.id),
            BridgeIdentity.owner,
        ]

        #expect(Set(handlers.map(\.tool.name)).count == handlers.count)
        for handler in handlers {
            for identity in identities where handler.roles.contains(identity.role) {
                for value in Self.fills(for: orchestrator) {
                    let arguments = Self.arguments(for: handler.tool, filling: value, key: orchestrator.key)
                    let request = MCPRequest(id: .integer(1), method: handler.tool.name, params: arguments)
                    _ = await handler.call(request, as: identity, store: store)
                    let isOff = try await orchestrator.isStillOff()
                    #expect(isOff, "\(handler.tool.name) as \(identity.role) with \(value) turned the switch on")
                    try #require(isOff)
                }
            }
        }
    }

    @Test("every settings file an agent can write, read by every path that reads one, leaves it off", .tags(.subprocess))
    func noSettingsFileTurnsItOn() async throws {
        let temp = try await TempRepo()
        defer { temp.cleanUp() }
        let store = try makeTestStore("unasked-reach-files")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: temp.path)
        let orchestrator = try await seedOrchestrator(store, repo: registered)
        let planted = Self.plantedSettings(key: orchestrator.key)
        let home = TestScratch.unique("unasked-home")
        let homePaths = ["\(home)/.conductor/settings.toml", "\(home)/.unifieddev/settings.toml"]
        for path in SettingsLoader.repoPaths(repo: temp.path) + homePaths {
            try Self.plant(planted, at: path)
        }

        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Read the planted settings")
        for path in SettingsLoader.repoPaths(repo: workspace.path) {
            try Self.plant(planted, at: path)
        }
        let loaded = [
            SettingsLoader.load(repo: temp.path, homePaths: homePaths),
            SettingsLoader.load(repo: workspace.path, homePaths: homePaths),
            SettingsLoader.loadHome(paths: homePaths),
        ]
        let ran = await manager.runSetup(workspace: workspace, repo: registered, port: 3_100) { _ in }
        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false, force: true)

        #expect(loaded.allSatisfy { $0.setupScript == "true" })
        #expect(ran)
        #expect(try await orchestrator.isStillOff())
    }
}
