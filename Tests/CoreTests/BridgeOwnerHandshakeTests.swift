import Foundation
import Testing
@testable import Core

@Suite("The owner's token at the handshake", .tags(.subprocess, .persistence, .security), .scratchDirectory)
struct BridgeOwnerHandshakeTests {
    private let ownerToken = "test-owner-token"

    private func greet(_ server: BridgeServer) async throws -> (welcome: BridgeWelcome, closedAfterwards: Bool) {
        let connection = try UnixSocketConnection.connect(to: server.socketPath)
        defer { connection.close() }
        var lines = connection.lines.makeAsyncIterator()
        let frame = BridgeHello(token: ownerToken, role: BridgeRole.owner.rawValue, shim: "test")
        connection.writeLine(String(decoding: try JSONEncoder().encode(frame), as: UTF8.self))
        let reply = try #require(await lines.next())
        let welcome = try JSONDecoder().decode(BridgeWelcome.self, from: Data(reply.utf8))
        guard !welcome.accepted else { return (welcome, false) }
        let closed = await lines.next() == nil
        return (welcome, closed)
    }

    private func server(_ store: Store) throws -> BridgeServer {
        let server = try BridgeServer(store: store)
        try server.start()
        server.registry.admit(ownerToken: ownerToken)
        return server
    }

    @Test("the kernel names this process as the peer on a local socket, and a closed connection names nobody")
    func peerProcessID() async throws {
        let server = try server(try makeTestStore("bridge-peer"))
        defer { server.stop() }

        let connection = try UnixSocketConnection.connect(to: server.socketPath)
        #expect(connection.peerProcessID == getpid())
        connection.close()
        #expect(connection.peerProcessID == nil)
    }

    @Test("the owner's token is refused from a shim running inside a live workspace, and welcome once it is archived")
    func ownerTokenInsideAWorkspace() async throws {
        let directory = try #require(ProcessWorkingDirectory.of(getpid()))
        let store = try makeTestStore("bridge-owner-placement")
        let repo = try await store.upsert(Repo(name: "billing", path: "/tmp/billing", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "standing here", branch: "unifieddev/standing-here",
            path: directory, baseBranch: "main"
        ))
        let server = try server(store)
        defer { server.stop() }

        let refused = try await greet(server)
        #expect(!refused.welcome.accepted)
        #expect(try #require(refused.welcome.problem).contains("'standing here'"))
        #expect(refused.closedAfterwards)

        try await store.update(workspaceID: workspace.id) { $0.archive() }
        let welcomed = try await greet(server)
        #expect(welcomed.welcome.accepted, "\(welcomed.welcome.problem ?? "")")
    }

    @Test("a session token from inside its own workspace is welcome, because the refusal is the owner's alone")
    func sessionTokenInsideItsOwnWorkspace() async throws {
        let directory = try #require(ProcessWorkingDirectory.of(getpid()))
        let store = try makeTestStore("bridge-session-placement")
        let repo = try await store.upsert(Repo(name: "billing", path: "/tmp/billing", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "standing here", branch: "unifieddev/standing-here",
            path: directory, baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let server = try server(store)
        defer { server.stop() }
        let token = server.registry.mint(sessionID: session.id, workspaceID: workspace.id, role: .workspace)

        let connection = try UnixSocketConnection.connect(to: server.socketPath)
        defer { connection.close() }
        var lines = connection.lines.makeAsyncIterator()
        let frame = BridgeHello(token: token, role: BridgeRole.workspace.rawValue, shim: "test")
        connection.writeLine(String(decoding: try JSONEncoder().encode(frame), as: UTF8.self))
        let reply = try #require(await lines.next())
        let welcome = try JSONDecoder().decode(BridgeWelcome.self, from: Data(reply.utf8))

        #expect(welcome.accepted, "\(welcome.problem ?? "")")
    }

    @Test("the owner's token from a directory in no workspace is welcome, as it always was")
    func ownerTokenOutsideWorkspaces() async throws {
        let store = try makeTestStore("bridge-owner-outside")
        let repo = try await store.upsert(Repo(name: "billing", path: "/tmp/billing", defaultBranch: "main"))
        _ = try await store.upsert(Workspace(
            repoID: repo.id, name: "elsewhere", branch: "unifieddev/elsewhere",
            path: TestScratch.unique("elsewhere"), baseBranch: "main"
        ))
        let server = try server(store)
        defer { server.stop() }

        let greeted = try await greet(server)
        #expect(greeted.welcome.accepted, "\(greeted.welcome.problem ?? "")")
    }
}
