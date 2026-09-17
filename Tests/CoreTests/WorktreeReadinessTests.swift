import Testing
@testable import Core

@Suite("What a terminal in a fresh worktree says")
struct WorktreeReadinessTests {
    @Test("a script that is running right now")
    func running() {
        #expect(WorktreeReadiness.of(isRunningSetup: true, setupState: .pending) == .installing)
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .running) == .installing)
    }

    @Test("a run in flight beats the verdict of the run before it")
    func runningBeatsTheStoredVerdict() {
        #expect(WorktreeReadiness.of(isRunningSetup: true, setupState: .failed) == .installing)
    }

    @Test("a failure is worth saying, because nothing is going to install anything now")
    func failed() {
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .failed) == .failed)
    }

    @Test("a finished worktree, and one with no script to run, say nothing")
    func ready() {
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .succeeded) == .ready)
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .skipped) == .ready)
    }

    @Test("a script that has not started yet says nothing either")
    func pendingSaysNothing() {
        #expect(WorktreeReadiness.of(isRunningSetup: false, setupState: .pending) == .ready)
    }

    @Test("only the ready case is silent")
    func onlyReadyIsSilent() {
        #expect(WorktreeReadiness.allCases.filter { $0.sentence == nil } == [.ready])
    }

    @Test("only an installing worktree is unsettled")
    func onlyInstallingIsUnsettled() {
        #expect(WorktreeReadiness.allCases.filter { !$0.isSettled } == [.installing])
    }
}
