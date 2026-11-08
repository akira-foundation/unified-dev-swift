import Testing
import Foundation
@testable import Core

@Suite("The delta reads the worktree it runs in", .scratchDirectory)
struct HandoffPromptWorktreeTests: HandoffTurnRunnerFixture {
    @Test("the prompt names the real branch and the real changed files")
    func thePromptNamesTheBranchAndFiles() async throws {
        let store = try makeTestStore("handoff-git")
        let repo = try await TempRepo()
        try await Shell.check("git", ["checkout", "-q", "-b", "feat/handoff"], cwd: repo.path)
        try repo.write("src/changed.txt", "one\ntwo\n")
        try await repo.commit("work")

        let stored = try await store.upsert(Repo(name: "r", path: repo.path))
        let workspace = try await store.upsert(Workspace(
            repoID: stored.id, name: "w", branch: "feat/handoff", path: repo.path, baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, model: "opus", agentKind: .claudeCode))
        let line = JSONValue.object(["type": .string("user"), "message": .object(["content": .string("earlier words")])])
        try await store.appendNext(sessionID: session.id, kind: .user, payload: Data(line.compactJSON.utf8))
        let moved = try await store.switchSegment(sessionID: session.id, to: toSegment(.codex, "gpt-5"))

        let prompt = try await store.handoffPrompt(
            "NEXT", session: moved, deliveredSeq: nil, workspacePath: repo.path, contextWindow: nil
        )

        #expect(prompt.contains("Worktree: branch feat/handoff."))
        #expect(prompt.contains("src/changed.txt (+2 -0)"))
        #expect(prompt.hasSuffix("\n\nNEXT"))
    }

    @Test("a chat with nothing owed never reads the worktree into its prompt")
    func nothingOwedLeavesThePromptAlone() async throws {
        let store = try makeTestStore("handoff-git-none")
        let session = try await makeSession(store, agent: .claudeCode, model: "opus")

        let prompt = try await store.handoffPrompt(
            "NEXT", session: session, deliveredSeq: nil, workspacePath: "/nowhere", contextWindow: nil
        )

        #expect(prompt == "NEXT")
    }
}
