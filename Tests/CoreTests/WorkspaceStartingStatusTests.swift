import Foundation
import Testing
@testable import Core

@Suite("Workspace still starting")
struct WorkspaceStartingStatusTests {
    private func workspace(setup: SetupState = .pending, additions: Int = 0) -> Workspace {
        Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: setup, additions: additions
        )
    }

    @Test("a workspace still starting keeps the setting up mark")
    func startingHoldsTheMark() {
        let status = WorkspaceStatus.resolve(
            workspace: workspace(), isRunning: false, pullRequest: nil, isStarting: true
        )

        #expect(status == .settingUp)
    }

    @Test("a running agent, a question and a failed setup all outrank the hold")
    func otherStatesOutrankTheHold() {
        let fresh = workspace()

        #expect(WorkspaceStatus.resolve(
            workspace: fresh, isRunning: true, pullRequest: nil, isStarting: true
        ) == .running)
        #expect(WorkspaceStatus.resolve(
            workspace: fresh, isRunning: false, pullRequest: nil,
            isAwaitingPermission: true, isStarting: true
        ) == .awaitingPermission)
        #expect(WorkspaceStatus.resolve(
            workspace: workspace(setup: .failed), isRunning: false, pullRequest: nil, isStarting: true
        ) == .setupFailed)
    }

    @Test("a workspace carried on from a branch with a pull request still says setting up first")
    func holdOutranksThePullRequest() throws {
        let carriedOn = workspace()
        let open = try GitHub.decodePullRequest(from: Data("""
            {"number":42,"title":"Better glyphs","url":"https://github.com/acme/app/pull/42",
            "state":"OPEN","isDraft":false,"headRefName":"feature/glyphs",
            "statusCheckRollup":[]}
            """.utf8))

        let held = WorkspaceStatus.resolve(
            workspace: carriedOn, isRunning: false, pullRequest: open, isStarting: true
        )
        let free = WorkspaceStatus.resolve(
            workspace: carriedOn, isRunning: false, pullRequest: open
        )

        #expect(held == .settingUp)
        #expect(free != .settingUp)
        #expect(free.describesPullRequest)
    }

    @Test("without the hold a fresh workspace resolves to its branch, as before")
    func defaultsToNotStarting() {
        #expect(WorkspaceStatus.resolve(workspace: workspace(), isRunning: false, pullRequest: nil) == .clean)
        #expect(WorkspaceStatus.resolve(
            workspace: workspace(additions: 2), isRunning: false, pullRequest: nil
        ) == .changed)
    }

    @Test("the hover card of a workspace still starting says the same as its row")
    func hoverCardReadsTheHold() {
        let held = WorkspaceHoverCard.make(workspace: workspace(), isStarting: true)
        let free = WorkspaceHoverCard.make(workspace: workspace())

        #expect(held.status == .settingUp)
        #expect(free.status == .clean)
    }
}
