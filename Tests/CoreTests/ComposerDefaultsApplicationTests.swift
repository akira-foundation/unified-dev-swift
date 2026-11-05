import Testing
import Foundation
@testable import Core

@Suite("Whether a chat takes the composer defaults", .tags(.persistence), .scratchDirectory)
struct ComposerDefaultsApplicationTests {
    private let codex = SessionSegmentTarget(agentKind: .codex, accountID: nil, model: "gpt-5", effort: "high")

    private func crewMember(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let parent = try await store.upsert(Session(workspaceID: workspace.id))
        return try await store.upsert(Session(workspaceID: workspace.id, parentSessionID: parent.id))
    }

    @Test("a chat that never spoke and was never prepared takes them")
    func newChatTakesThem() {
        #expect(ComposerDefaults.applies(wasPrepared: false, agentSessionID: nil, messageCount: 0))
    }

    @Test("a chat already prepared, with a native session, or with any row, does not")
    func spokenOrPreparedChatKeepsItsOwn() {
        #expect(!ComposerDefaults.applies(wasPrepared: true, agentSessionID: nil, messageCount: 0))
        #expect(!ComposerDefaults.applies(wasPrepared: false, agentSessionID: "s1", messageCount: 0))
        #expect(!ComposerDefaults.applies(wasPrepared: false, agentSessionID: nil, messageCount: 1))
    }

    @Test("switching a chat marks its defaults as applied")
    func switchLeavesTheKey() async throws {
        let store = try makeTestStore("defaults-key")
        let member = try await crewMember(store)
        try await store.update(sessionID: member.id) { $0.agentSessionID = "c1" }

        try await store.switchSegment(sessionID: member.id, to: codex)

        let key = ComposerControls.defaultsAppliedKey(sessionID: member.id)
        #expect(try await store.setting(key) == "1")
    }

    @Test("a switched crew member with no key and no native session is not given the defaults")
    func switchedCrewMemberIsNotReset() async throws {
        let store = try makeTestStore("defaults-crew")
        let member = try await crewMember(store)
        try await store.update(sessionID: member.id) { $0.agentSessionID = "c1" }
        try await store.switchSegment(sessionID: member.id, to: codex)

        let switched = try #require(try await store.session(id: member.id))
        let key = ComposerControls.defaultsAppliedKey(sessionID: member.id)
        let applies = ComposerDefaults.applies(
            wasPrepared: try await store.setting(key) == "1",
            agentSessionID: switched.agentSessionID,
            messageCount: try await store.messageCount(sessionID: member.id)
        )

        #expect(switched.agentSessionID == nil)
        #expect(!applies)
    }
}
