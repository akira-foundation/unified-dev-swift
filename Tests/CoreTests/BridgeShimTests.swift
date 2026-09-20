import Foundation
import Testing
@testable import Core

private let shimPath = BridgeRegistration.shimPath()

@Suite("BridgeShim", .enabled(if: shimPath != nil), .tags(.subprocess), .scratchDirectory)
struct BridgeShimTests {
    private func launch(_ environment: [String: String]) throws -> StreamingProcess {
        let process = StreamingProcess(
            executable: try #require(shimPath),
            arguments: [],
            cwd: NSTemporaryDirectory(),
            environment: environment,
            mergeStderr: false
        )
        try process.start()
        return process
    }

    private func scratchSocket() -> String {
        (TestProcessScratch.root as NSString)
            .appendingPathComponent("shim-\(UUID().uuidString.prefix(8)).sock")
    }

    @Test("relays a whole MCP conversation between its stdin and the app", .timeLimit(.minutes(1)))
    func relaysAConversation() async throws {
        let store = try makeTestStore("shim")
        let repo = try await store.upsert(Repo(name: "billing", path: "/tmp/billing"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id,
            name: "cut the index",
            branch: "unifieddev/cut-the-index",
            path: "/tmp/billing-cut",
            baseBranch: "main",
            origin: .user
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id))

        let socketPath = scratchSocket()
        let server = BridgeServer(store: store, socketPath: socketPath)
        try server.start()
        defer { server.stop() }

        let attachment = server.attach(
            session: session,
            workspace: workspace,
            shimPath: try #require(shimPath)
        )
        let process = try launch(attachment.environment)
        defer { process.terminate() }

        var replies = process.lines.makeAsyncIterator()
        process.writeLine(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#)
        let initialized = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(try #require(try await replies.next()).utf8)
        )
        #expect(initialized["result"]?["serverInfo"]?["name"] == .string(BridgeRegistration.serverName))

        process.writeLine(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
        process.writeLine(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"whoami","arguments":{}}}"#)
        let called = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(try #require(try await replies.next()).utf8)
        )
        #expect(called["id"] == .integer(2))

        let text = try #require(called["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(text.contains("cut the index"))
        #expect(text.contains("unifieddev/cut-the-index"))
        #expect(text.contains("billing"))
    }

    @Test("closing its stdin ends the process, so no shim outlives the CLI that started it",
          .timeLimit(.minutes(1)))
    func stdinCloseEndsIt() async throws {
        let store = try makeTestStore("shim-exit")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id,
            name: "w",
            branch: "b",
            path: "/tmp/w",
            baseBranch: "main",
            origin: .user
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id))

        let server = BridgeServer(store: store, socketPath: scratchSocket())
        try server.start()
        defer { server.stop() }

        let attachment = server.attach(
            session: session,
            workspace: workspace,
            shimPath: try #require(shimPath)
        )
        let process = try launch(attachment.environment)
        process.closeStdin()
        #expect(await process.exitStatus == BridgeShim.Exit.ok)
    }

    @Test("says so and exits when it is run without an environment", .timeLimit(.minutes(1)))
    func withoutAnEnvironment() async throws {
        let process = try launch(["PATH": "/usr/bin:/bin"])
        var complaints: [String] = []
        for await line in process.errorLines { complaints.append(line) }

        #expect(await process.exitStatus == BridgeShim.Exit.notConfigured)
        #expect(complaints.joined(separator: " ").contains(BridgeProtocol.socketVariable))
    }

    @Test("it names the variable that is missing rather than blaming both")
    func namesTheMissingVariable() {
        #expect(BridgeShim.missingEnvironment([
            BridgeProtocol.socketVariable: "/tmp/a.sock",
            BridgeProtocol.tokenVariable: "t",
        ]) == nil)

        let noToken = try! #require(BridgeShim.missingEnvironment([BridgeProtocol.socketVariable: "/tmp/a.sock"]))
        #expect(noToken.contains("\(BridgeProtocol.tokenVariable) was not set"))
        #expect(!noToken.contains("Neither"))

        let noSocket = try! #require(BridgeShim.missingEnvironment([BridgeProtocol.tokenVariable: "t"]))
        #expect(noSocket.contains("\(BridgeProtocol.socketVariable) was not set"))

        let blank = try! #require(BridgeShim.missingEnvironment([
            BridgeProtocol.socketVariable: "",
            BridgeProtocol.tokenVariable: "t",
        ]))
        #expect(blank.contains("\(BridgeProtocol.socketVariable) was not set"))

        #expect(BridgeShim.missingEnvironment([:])?.contains("Neither was set") == true)
    }

    @Test("names the socket it could not reach, rather than hanging", .timeLimit(.minutes(1)))
    func withoutAnApp() async throws {
        let socketPath = scratchSocket()
        let process = try launch([
            BridgeProtocol.socketVariable: socketPath,
            BridgeProtocol.tokenVariable: "t",
            BridgeProtocol.roleVariable: "workspace",
        ])
        var complaints: [String] = []
        for await line in process.errorLines { complaints.append(line) }

        #expect(await process.exitStatus == BridgeShim.Exit.cannotReachUnifiedDev)
        #expect(complaints.joined(separator: " ").contains(socketPath))
    }

    @Test("says so and fails when Unified Dev goes away with a call in flight", .timeLimit(.minutes(1)))
    func unifieddevQuitsMidCall() async throws {
        let socketPath = scratchSocket()
        let welcome = String(
            decoding: try JSONEncoder().encode(BridgeWelcome.accepting()),
            as: UTF8.self
        )
        let listener = try UnixSocketListener(path: socketPath) { connection in
            Task {
                var incoming = connection.lines.makeAsyncIterator()
                _ = await incoming.next()
                connection.writeLine(welcome)
                _ = await incoming.next()
                connection.close()
            }
        }
        defer { listener.stop() }

        let process = try launch([
            BridgeProtocol.socketVariable: socketPath,
            BridgeProtocol.tokenVariable: "t",
            BridgeProtocol.roleVariable: "workspace",
        ])
        defer { process.terminate() }
        process.writeLine(#"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami"}}"#)

        var complaints: [String] = []
        for await line in process.errorLines { complaints.append(line) }

        #expect(await process.exitStatus == BridgeShim.Exit.cannotReachUnifiedDev)
        #expect(complaints.joined(separator: " ").contains("before answering"))
    }

    @Test("prints Unified Dev's refusal and exits when the protocol does not match", .timeLimit(.minutes(1)))
    func refusedAtTheHandshake() async throws {
        let socketPath = scratchSocket()
        let refusal = BridgeWelcome.refusing("Unified Dev speaks 1 and this bridge speaks 2. Quit and reopen Unified Dev.")
        let encoded = String(decoding: try JSONEncoder().encode(refusal), as: UTF8.self)
        let listener = try UnixSocketListener(path: socketPath) { connection in
            Task {
                var incoming = connection.lines.makeAsyncIterator()
                _ = await incoming.next()
                connection.writeLine(encoded)
                connection.close()
            }
        }
        defer { listener.stop() }

        let process = try launch([
            BridgeProtocol.socketVariable: socketPath,
            BridgeProtocol.tokenVariable: "t",
            BridgeProtocol.roleVariable: "workspace",
        ])
        var complaints: [String] = []
        for await line in process.errorLines { complaints.append(line) }

        #expect(await process.exitStatus == BridgeShim.Exit.refused)
        #expect(complaints.joined(separator: " ").contains("Quit and reopen Unified Dev"))
    }
}
