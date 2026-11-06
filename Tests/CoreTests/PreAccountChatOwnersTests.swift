import Testing
import Foundation
@testable import Core

@Suite("Chats from before accounts belong to their provider's default account", .tags(.persistence), .scratchDirectory)
struct PreAccountChatOwnersTests {
    private struct Seeded {
        let path: String
        let repo: Repo
        let claude: Session
        let codex: Session
        let grok: Session
        let fresh: Session
    }

    private let defaultClaude = AgentAccountHome.defaultID(for: .claudeCode)
    private let defaultCodex = AgentAccountHome.defaultID(for: .codex)

    private func seeded(_ name: String) async throws -> Seeded {
        let path = TestScratch.unique(name) + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "billing", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "invoices", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let claude = try await store.upsert(Session(workspaceID: workspace.id, agentSessionID: "claude-native"))
        let codex = try await store.upsert(Session(
            workspaceID: workspace.id, agentSessionID: "codex-native", model: "gpt-5", agentKind: .codex
        ))
        let grok = try await store.upsert(Session(
            workspaceID: workspace.id, agentSessionID: "grok-native", model: "grok-4", agentKind: .grok
        ))
        let fresh = try await store.upsert(Session(workspaceID: workspace.id))
        try await store.appendNext(sessionID: claude.id, kind: .assistantText, payload: Data())
        return Seeded(path: path, repo: repo, claude: claude, codex: codex, grok: grok, fresh: fresh)
    }

    private func fromBeforeAccounts(_ name: String) async throws -> (Seeded, Store) {
        let seeded = try await seeded(name)
        let raw = try SQLiteDatabase(path: seeded.path)
        try raw.execute("DROP TABLE session_segments;")
        try raw.execute("DELETE FROM agent_accounts;")
        try raw.setUserVersion(0)
        return (seeded, try Store(path: seeded.path))
    }

    @Test("a chat with history from before accounts is recorded on its provider's default account, and so is its segment")
    func aChatFromBeforeAccountsIsRecordedOnTheDefault() async throws {
        let (seeded, store) = try await fromBeforeAccounts("pre-account-default")

        #expect(try await store.session(id: seeded.claude.id)?.accountID == defaultClaude)
        #expect(try await store.activeSegment(sessionID: seeded.claude.id)?.accountID == defaultClaude)
        #expect(try await store.session(id: seeded.codex.id)?.accountID == defaultCodex)
        #expect(try await store.activeSegment(sessionID: seeded.codex.id)?.accountID == defaultCodex)
        let rows = try await store.agentAccounts()
        #expect(Set(rows.map(\.id)) == [defaultClaude, defaultCodex])
        let allDefault = rows.allSatisfy(\.isDefault)
        #expect(allDefault)
        #expect(rows.first { $0.id == defaultCodex }?.provider == .codex)
    }

    @Test("a chat with no history, or of an agent with no default account, is left unrecorded")
    func chatsWithNoKnownOwnerAreLeftAlone() async throws {
        let (seeded, store) = try await fromBeforeAccounts("pre-account-unknown")

        #expect(try await store.session(id: seeded.fresh.id)?.accountID == nil)
        #expect(try await store.activeSegment(sessionID: seeded.fresh.id)?.accountID == nil)
        #expect(try await store.session(id: seeded.grok.id)?.accountID == nil)
        #expect(try await store.activeSegment(sessionID: seeded.grok.id)?.accountID == nil)
    }

    @Test("a chat with history and no owner in a database that already had accounts stays unknown")
    func aDatabaseWithAccountsKeepsItsUnknownChats() async throws {
        let seeded = try await seeded("pre-account-later")
        let raw = try SQLiteDatabase(path: seeded.path)
        let version = try raw.readUserVersion()
        try raw.setUserVersion(version - 1)

        let store = try Store(path: seeded.path)

        #expect(try await store.session(id: seeded.claude.id)?.accountID == nil)
        #expect(try await store.activeSegment(sessionID: seeded.claude.id)?.accountID == nil)
        #expect(try SQLiteDatabase(path: seeded.path).readUserVersion() == version)
    }

    @Test("a project that chooses another account moves the old chat there instead of resuming it under that account")
    func choosingAnotherAccountMovesTheOldChat() async throws {
        let (seeded, store) = try await fromBeforeAccounts("pre-account-choice")
        let client = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("client"),
            directory: URL(filePath: "/accounts/claudeCode/client", directoryHint: .isDirectory), isDefault: false
        )
        let session = try #require(try await store.session(id: seeded.claude.id))

        let settled = AgentSessionSettlement.decide(session: session, account: client, purpose: .sending)

        #expect(settled.switchTarget?.accountID == client.id)
        #expect(AgentSessionSettlement.resumable(session: session, account: client) == nil)
    }

    @Test("leaving for another agent and coming back resumes the old chat's own conversation")
    func comingBackResumesTheParkedConversation() async throws {
        let (seeded, store) = try await fromBeforeAccounts("pre-account-return")
        let original = try #require(try await store.activeSegment(sessionID: seeded.claude.id))
        for provider in [AgentKind.claudeCode, .codex] {
            try await store.addIfMissing(AgentAccountRow(
                id: AgentAccountHome.defaultID(for: provider), provider: provider,
                directory: "/home/\(provider.rawValue)", isDefault: true
            ))
        }

        _ = try await store.switchSegment(sessionID: seeded.claude.id, to: SessionSegmentTarget(
            agentKind: .codex, accountID: defaultCodex, model: "gpt-5", effort: ""
        ))
        let back = try await store.switchSegment(sessionID: seeded.claude.id, to: SessionSegmentTarget(
            agentKind: .claudeCode, accountID: defaultClaude, model: seeded.claude.model, effort: ""
        ))

        let active = try #require(try await store.activeSegment(sessionID: seeded.claude.id))
        #expect(active.id == original.id)
        #expect(active.cursorSeq == original.cursorSeq)
        #expect(back.agentSessionID == "claude-native")
        #expect(try await store.segments(sessionID: seeded.claude.id).count == 2)
    }
}
