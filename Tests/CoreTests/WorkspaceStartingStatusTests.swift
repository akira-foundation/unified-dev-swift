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
