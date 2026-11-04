import Testing
import Foundation
@testable import Core

@Suite("Recording on a session which account it runs under", .tags(.persistence), .scratchDirectory)
struct AgentAccountSessionRecordTests {
    private var providerDefault: AgentAccountHome {
        AgentAccountHome.defaultHome(for: .claudeCode, home: AccountFixture.user)!
    }

    private func seed(_ store: Store, agentSessionID: String? = nil) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, agentSessionID: agentSessionID))
    }

    private func settle(
        _ session: Session,
        on account: AgentAccountHome,
        deliberate: Bool = false,
        in store: Store
    ) async throws {
        let settlement = AgentSessionSettlement.decide(
            session: session, account: account, purpose: .sending, isDeliberateSwitch: deliberate
        )
        try await AgentSessionRecord.write(settlement, session: session.id, account: account, in: store)
    }

    @Test("a first send on a database that has never chosen an account records the synthesised default")
    func theSynthesisedDefaultIsStoredBeforeItIsRecorded() async throws {
        let store = try makeTestStore("session-record")
        let session = try await seed(store)
        let home = providerDefault

        try await settle(session, on: home, in: store)

        #expect(try await store.session(id: session.id)?.accountID == home.id)
        let rows = try await store.agentAccounts()
        #expect(rows.map(\.id) == [home.id])
        #expect(rows.first?.isDefault == true)
        #expect(rows.first?.directory == home.directory.path)
    }

    @Test("a deliberate switch to the default clears the stored conversation and records the account")
    func aDeliberateSwitchToTheDefaultWritesBothColumns() async throws {
        let store = try makeTestStore("session-record")
        let session = try await seed(store, agentSessionID: "agent-session-1")
        let home = providerDefault

        try await settle(session, on: home, deliberate: true, in: store)

        let read = try #require(try await store.session(id: session.id))
        #expect(read.agentSessionID == nil)
        #expect(read.accountID == home.id)
    }

    @Test("recording the default twice leaves one row and the same choice")
    func recordingTwiceIsHarmless() async throws {
        let store = try makeTestStore("session-record")
        let first = try await seed(store)
        let second = try await seed(store)
        let home = providerDefault

        try await settle(first, on: home, in: store)
        try await settle(second, on: home, in: store)

        #expect(try await store.agentAccounts().count == 1)
        #expect(try await store.session(id: second.id)?.accountID == home.id)
    }

    @Test("a settlement that cannot record its account leaves the conversation pointer alone")
    func aRecordThatFailsDestroysNothing() async throws {
        let store = try makeTestStore("session-record")
        let session = try await seed(store, agentSessionID: "agent-session-1")
        let forgotten = AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID("forgotten"),
            directory: URL(filePath: "/accounts/forgotten", directoryHint: .isDirectory),
            isDefault: false
        )
        let settlement = AgentSessionSettlement.decide(
            session: session, account: forgotten, purpose: .sending, isDeliberateSwitch: true
        )
        #expect(settlement.clearsStoredID)

        await #expect(throws: (any Error).self) {
            try await AgentSessionRecord.write(
                settlement, session: session.id, account: forgotten, in: store
            )
        }

        let read = try #require(try await store.session(id: session.id))
        #expect(read.agentSessionID == "agent-session-1")
        #expect(read.accountID == nil)
    }

    @Test("a chat whose account is elsewhere keeps both its conversation and its recorded account")
    func anElsewhereChatIsLeftAlone() async throws {
        let store = try makeTestStore("session-record")
        let session = try await seed(store, agentSessionID: "agent-session-1")
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: "/accounts/work"
        )
        try await store.add(work)
        try await store.update(sessionID: session.id, accountID: work.id)
        let stored = try #require(try await store.session(id: session.id))

        try await settle(stored, on: providerDefault, in: store)

        let read = try #require(try await store.session(id: session.id))
        #expect(read.agentSessionID == "agent-session-1")
        #expect(read.accountID == work.id)
    }
}
