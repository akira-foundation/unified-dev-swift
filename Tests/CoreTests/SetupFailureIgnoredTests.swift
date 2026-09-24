import Foundation
import Testing
@testable import Core

@Suite("An ignored setup failure", .tags(.persistence), .scratchDirectory)
struct SetupFailureIgnoredTests {
    private func workspace(_ state: SetupState, log: String = "") -> Workspace {
        Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: state, setupLog: log
        )
    }

    @Test("only a failure can be ignored, and the log it left is kept")
    func ignoringAFailure() {
        var subject = workspace(.failed, log: "sudo: a password is required")
        let first = subject.apply(.failureIgnored)
        let second = subject.apply(.failureIgnored)
        #expect(first == .moves(to: .ignored))
        #expect(second == .unchanged)
        #expect(subject.setupState == .ignored)
        #expect(subject.setupLog == "sudo: a password is required")
    }

    @Test("there is nothing to ignore outside a failure", arguments: [
        SetupState.pending, .running, .succeeded, .skipped,
    ])
    func ignoringNothing(from state: SetupState) {
        #expect(state.transition(on: .failureIgnored) == .refused)
    }

    @Test("an ignored failure can still be run again")
    func runningAnIgnoredFailure() {
        #expect(SetupState.ignored.transition(on: .runStarted) == .moves(to: .running))
    }

    @Test("an ignored failure answers the rest of the lifecycle the way a failure did")
    func ignoredAnswersTheRest() {
        #expect(SetupState.ignored.transition(on: .runFinished(succeeded: true, log: "x")) == .refused)
        #expect(SetupState.ignored.transition(on: .runInterrupted) == .refused)
        #expect(SetupState.ignored.transition(on: .runSkipped(note: nil)) == .moves(to: .skipped))
        #expect(SetupState.ignored.transition(on: .worktreeRebuilt(hasSetupScript: true)) == .moves(to: .pending))
    }

    @Test("a refusal to ignore is recorded under the event's own name")
    func refusalIsRecorded() {
        var subject = workspace(.succeeded)
        let refused = subject.apply(.failureIgnored)
        #expect(refused == .refused)
        let recorded = RefusedTransitions.recent.contains {
            $0.sentence == "setup refused failureIgnored from succeeded"
        }
        #expect(recorded)
    }

    @Test("an ignored failure no longer reads as a failed setup")
    func ignoredIsNotSetupFailed() {
        let status = WorkspaceStatus.resolve(workspace: workspace(.ignored), isRunning: false, pullRequest: nil)
        #expect(status == .clean)
    }

    @Test("a terminal in the worktree stops warning, and run scripts may start")
    func ignoredCountsAsReady() {
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .ignored) == .ready)
        #expect(RunScriptAutostart.isTimely(isRunningSetup: false, setupState: .ignored, hasSetupScript: true))
    }

    @Test("ignoring goes through the store as an update, and workspace_list reports it")
    func storeAndBridge() async throws {
        let store = try makeTestStore("setup-ignored")
        let repo = try await store.upsert(Repo(name: "ember", path: "/tmp/ember"))
        let failed = try await store.upsert(Workspace(
            repoID: repo.id, name: "needs a password", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: .failed, setupLog: "sudo: a password is required"
        ))

        _ = try await store.update(workspaceID: failed.id) { $0.apply(.failureIgnored) }

        let reread = try #require(try await store.workspace(id: failed.id))
        #expect(reread.setupState == .ignored)
        #expect(reread.setupLog == "sudo: a password is required")

        let request = MCPRequest(id: .number(1), method: "workspace_list", params: .object([:]))
        let result = await WorkspaceListTool().call(request, as: .owner, store: store)
        let rows = try #require(JSONValue.parse(result.text)?["workspaces"]?.arrayValue)
        let row = try #require(rows.first { $0["name"]?.stringValue == "needs a password" })
        #expect(row["setup_state"]?.stringValue == "ignored")
        #expect(row["status"]?.stringValue == "clean")
    }
}
