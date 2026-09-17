import Testing
import Foundation
@testable import Core

@Suite("A chat with no workspace", .tags(.persistence), .scratchDirectory)
struct SessionWithoutWorkspaceTests {
    private static let oldSessionsTable = """
        CREATE TABLE sessions_old (
            id TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            agent_session_id TEXT,
            model TEXT NOT NULL DEFAULT 'opus',
            effort TEXT NOT NULL DEFAULT 'high',
            agent_kind TEXT NOT NULL DEFAULT 'claudeCode',
            permission_mode TEXT NOT NULL DEFAULT 'acceptEdits',
            state TEXT NOT NULL DEFAULT 'idle',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            archived_at REAL,
            last_read_seq INTEGER NOT NULL DEFAULT 0,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cost_usd REAL NOT NULL DEFAULT 0,
            context_tokens INTEGER NOT NULL DEFAULT 0
        );

        INSERT INTO sessions_old SELECT
            id, workspace_id, title, agent_session_id, model, effort, agent_kind,
            permission_mode, state, sort_order, created_at, updated_at, archived_at,
            last_read_seq, input_tokens, output_tokens, cost_usd, context_tokens
        FROM sessions;

        DROP TABLE sessions;
        ALTER TABLE sessions_old RENAME TO sessions;
        CREATE INDEX IF NOT EXISTS sessions_workspace ON sessions(workspace_id);
        """

    private func isNullable(_ path: String) throws -> Bool {
        let raw = try SQLiteDatabase(path: path)
        let column = try raw.query("PRAGMA table_info(sessions);")
            .first { $0.string("name") == "workspace_id" }
        return column?.int("notnull") == 0
    }

    @Test("a chat with no worktree round-trips")
    func roundTrips() async throws {
        let store = try makeTestStore("ask-session")
        let session = try await store.upsert(Session(workspaceID: nil, title: "Ask Unified Dev"))

        let loaded = try #require(try await store.session(id: session.id))
        #expect(loaded.workspaceID == nil)
        #expect(loaded.title == "Ask Unified Dev")
    }

    @Test("it is invisible to every list that is about a worktree")
    func invisibleToWorkspaceLists() async throws {
        let store = try makeTestStore("ask-invisible")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/r-w", baseBranch: "main"
        ))
        let inWorktree = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let ask = try await store.upsert(Session(workspaceID: nil, title: "Ask Unified Dev"))

        #expect(try await store.sessions(workspaceID: workspace.id).map(\.id) == [inWorktree.id])
        #expect(try await store.sessionsWithoutWorkspace().map(\.id) == [ask.id])
    }

    @Test("a running chat with no worktree stays out of the workspace activity mirror")
    func staysOutOfActivity() async throws {
        let store = try makeTestStore("ask-activity")
        var ask = Session(workspaceID: nil, title: "Ask Unified Dev")
        ask.apply(.turnStarted)
        _ = try await store.upsert(ask)

        #expect(try await store.sessionActivity().isEmpty)
        #expect(try await store.session(id: ask.id)?.state == .running)
    }

    @Test("the rebuild relaxes the column without taking the transcript with it")
    func rebuildKeepsMessages() async throws {
        let path = TestScratch.unique("ask-rebuild") + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/r-w", baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        for index in 0..<5 {
            _ = try await store.appendNext(
                sessionID: session.id, kind: .user, payload: Data("line \(index)".utf8)
            )
        }

        let raw = try SQLiteDatabase(path: path)
        try raw.execute("PRAGMA foreign_keys = OFF;")
        try raw.execute(Self.oldSessionsTable)
        try raw.setUserVersion(0)
        #expect(try isNullable(path) == false)

        let reopened = try Store(path: path)
        #expect(try isNullable(path))
        #expect(try await reopened.messageCount(sessionID: session.id) == 5)
        #expect(try await reopened.session(id: session.id)?.title == "Chat")
        #expect(try await reopened.sessions(workspaceID: workspace.id).count == 1)

        let ask = try await reopened.upsert(Session(workspaceID: nil, title: "Ask Unified Dev"))
        #expect(try await reopened.sessionsWithoutWorkspace().map(\.id) == [ask.id])
    }

    @Test("replaying the migration over the new shape changes nothing")
    func replaysOverTheNewShape() async throws {
        let path = TestScratch.unique("ask-replay") + ".sqlite"
        let store = try Store(path: path)
        let ask = try await store.upsert(Session(workspaceID: nil, title: "Ask Unified Dev"))
        _ = try await store.appendNext(sessionID: ask.id, kind: .user, payload: Data("hello".utf8))

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        #expect(try isNullable(path))
        #expect(try await reopened.sessionsWithoutWorkspace().map(\.id) == [ask.id])
        #expect(try await reopened.messageCount(sessionID: ask.id) == 1)
    }
}
