import Foundation
import Testing
@testable import Core

private let liveEnabled = ProcessInfo.processInfo.environment["UD_LIVE"] == "1"
private let shimPath = BridgeRegistration.shimPath()

@Suite("LiveBridge", .enabled(if: liveEnabled && shimPath != nil), .tags(.subprocess), .scratchDirectory)
struct LiveBridgeTests {
    @Test("a real agent lists the bridge's tools and calls one", .timeLimit(.minutes(5)))
    func callsWhoami() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let store = try makeTestStore("live-bridge")
        let project = try await store.upsert(Repo(name: "billing", path: repo.path, defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: project.id,
            name: "cut the invoice index",
            branch: "unifieddev/cut-the-invoice-index",
            path: repo.path,
            baseBranch: "main",
            origin: .agent(parentWorkspaceID: WorkspaceID("parent-1"), spawnToolUseID: "toolu_live")
        ))
        let session = try await store.upsert(Session(
            workspaceID: workspace.id,
            model: "haiku",
            permissionMode: .acceptEdits
        ))

        let server = try BridgeServer(store: store)
        try server.start()
        defer { server.stop() }

        let handle = try #require(server.register(session: session, workspace: workspace))
        #expect(handle.attachment.role == .workspace)
        let configPath = try #require(handle.mcpConfigPath)

        let runner = AgentRunner(
            workspacePath: repo.path,
            session: session,
            store: store,
            mcpConfigPath: configPath
        )
        let arguments = await runner.launch().arguments
        #expect(arguments.contains("--mcp-config"))
        #expect(!arguments.contains("--strict-mcp-config"))

        let log = LiveBridgeLog()
        let pump = Task { for await event in runner.events { log.record(event) } }
        defer { pump.cancel() }

        let answered = Answered()
        let approvals = Task {
            while !Task.isCancelled {
                for ask in (try? await store.pendingPermissionAsks()) ?? [] where ask.sessionID == session.id {
                    answered.record(ask.ask.toolName)
                    await runner.answer(requestID: ask.requestID, decision: .allow(scope: .once))
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { approvals.cancel() }

        try await runner.send("""
            Call the whoami tool from the unifieddev-workspace-bridge MCP server. \
            Reply with only the workspace name it reports and nothing else.
            """)

        await waitUntil("the turn finished", within: .seconds(180)) { log.sawResult }

        print("LiveBridge: bridge tools offered: \(log.bridgeTools)")
        print("LiveBridge: mcp_servers on init: \(log.mcpServersLine)")
        print("LiveBridge: tools called: \(log.calledTools)")
        print("LiveBridge: permission asks: \(answered.toolNames)")
        print("LiveBridge: reply: \(log.resultSummary)")

        #expect(log.bridgeTools == ["mcp__\(BridgeRegistration.serverName)__whoami"])
        #expect(log.calledTools.contains { $0.contains("whoami") })
        #expect(log.mcpServersLine.contains(BridgeRegistration.serverName))
        #expect(log.sawResult)
        #expect(log.resultSummary.lowercased().contains("cut the invoice index"))

        let stored = try await store.session(id: session.id)
        print("LiveBridge: cost $\(stored?.costUSD ?? 0)")
    }
}

final class LiveBridgeLog: @unchecked Sendable {
    private let lock = NSLock()
    private var initTools: [String] = []
    private var servers = ""
    private var called: [String] = []
    private var result: String?

    var bridgeTools: [String] {
        lock.lock(); defer { lock.unlock() }
        return initTools.filter { $0.lowercased().contains("unifieddev") }
    }

    var mcpServersLine: String {
        lock.lock(); defer { lock.unlock() }
        return servers
    }

    var calledTools: [String] {
        lock.lock(); defer { lock.unlock() }
        return called
    }

    var sawResult: Bool {
        lock.lock(); defer { lock.unlock() }
        return result != nil
    }

    var resultSummary: String {
        lock.lock(); defer { lock.unlock() }
        return result ?? ""
    }

    func record(_ event: AgentEvent) {
        lock.lock(); defer { lock.unlock() }
        switch event {
        case .initialized(let start):
            initTools = start.tools
            if let raw = try? JSONDecoder().decode(JSONValue.self, from: start.raw),
               let list = raw["mcp_servers"],
               let data = try? JSONEncoder().encode(list) {
                servers = String(decoding: data, as: UTF8.self)
            }
        case .toolUse(let use):
            called.append(use.name)
        case .result(let outcome):
            result = outcome.summary
        default:
            break
        }
    }
}

final class Answered: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []

    var toolNames: [String] {
        lock.lock(); defer { lock.unlock() }
        return seen
    }

    func record(_ subject: String) {
        lock.lock(); defer { lock.unlock() }
        if !seen.contains(subject) { seen.append(subject) }
    }
}
