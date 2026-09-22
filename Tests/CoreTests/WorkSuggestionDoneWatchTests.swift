import Foundation
import Testing
@testable import Core

@Suite("A started suggestion tells the chat that suggested it", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionDoneWatchTests {
    private typealias Seams = WorkSuggestionLaunchSeams
    private typealias Fixture = WorkSuggestionLaunchFixture

    @Test("a suggestion started as a new workspace promises to tell the chat that suggested it")
    func startedCardLeavesAWatch() async throws {
        let f = try await Fixture.make("done-card")
        let s = try await f.suggest()

        let outcome = await Seams(store: f.store).launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome.startedSuggestion != nil, "\(outcome)")
        let watches = try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: WorkspaceID("w-born-1"))
        let watch = try #require(watches.first)
        #expect(watches.count == 1)
        #expect(watch.cause == .start)
        #expect(watch.watcherSessionID == f.chat.id)
        #expect(watch.target.workspace == "Keep the last row")
    }

    @Test("a press that finds the workspace already made writes no second promise")
    func alreadyStartedLeavesNone() async throws {
        let f = try await Fixture.make("done-card-again")
        let s = try await f.suggest()
        let order = AgentWorkspaceOrder(
            prompt: WorkSuggestionBrief.task(from: s.prompt), name: WorkspaceName.given(s.title)
        )
        let made = try await f.store.upsert(Workspace(
            repoID: f.repo.id, name: "Keep the last row", branch: "claude/keep-the-last-row",
            path: "/tmp/keep-the-last-row", baseBranch: "main",
            origin: .agent(parentWorkspaceID: f.workspace.id, spawnToolUseID: order.spawnID(suggestion: s.id))
        ))

        let outcome = await Seams(store: f.store).launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome.startedSuggestion != nil, "\(outcome)")
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: made.id).isEmpty)
    }

    @Test("an Ask chat's suggestion has no workspace chat to tell, so nothing is promised")
    func askLeavesNone() async throws {
        let f = try await Fixture.make("done-card-ask")
        let ask = try await f.store.upsert(Session(workspaceID: nil, title: "Ask"))
        let s = try await f.suggest(target: .project(f.repo.id), from: ask)

        let outcome = await Seams(store: f.store).launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome.startedSuggestion != nil, "\(outcome)")
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: WorkspaceID("w-born-1")).isEmpty)
    }
}
