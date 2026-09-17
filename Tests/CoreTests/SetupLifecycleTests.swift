import Foundation
import Testing
@testable import Core

@Suite("The setup lifecycle")
struct SetupLifecycleTests {
    private func workspace(_ state: SetupState, log: String = "") -> Workspace {
        Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: state, setupLog: log
        )
    }

    @Test("a run starts from every state that is not already running", arguments: [
        SetupState.pending, .succeeded, .failed, .skipped,
    ])
    func runStarts(from state: SetupState) {
        #expect(state.transition(on: .runStarted) == .moves(to: .running))
    }

    @Test("a second start while a run is in flight changes nothing and is not refused")
    func secondStart() {
        #expect(SetupState.running.transition(on: .runStarted) == .unchanged)
    }

    @Test("a finished run is only ever filed against the run that was started", arguments: [
        SetupState.pending, .succeeded, .failed, .skipped,
    ])
    func outcomeOutsideARun(from state: SetupState) {
        #expect(state.transition(on: .runFinished(succeeded: true, log: "x")) == .refused)
        #expect(state.transition(on: .runFinished(succeeded: false, log: "x")) == .refused)
    }

    @Test("a run in flight ends where its exit status says")
    func outcomeInsideARun() {
        #expect(
            SetupState.running.transition(on: .runFinished(succeeded: true, log: "x"))
                == .moves(to: .succeeded)
        )
        #expect(
            SetupState.running.transition(on: .runFinished(succeeded: false, log: "x"))
                == .moves(to: .failed)
        )
    }

    @Test("nothing to run is decided before anything is launched, never during", arguments: [
        SetupState.pending, .succeeded, .failed,
    ])
    func skipping(from state: SetupState) {
        #expect(state.transition(on: .runSkipped(note: nil)) == .moves(to: .skipped))
    }

    @Test("a live run cannot be filed as a run that never happened")
    func skippingARunningScript() {
        #expect(SetupState.running.transition(on: .runSkipped(note: nil)) == .refused)
        #expect(SetupState.skipped.transition(on: .runSkipped(note: nil)) == .unchanged)
    }

    @Test("the app dying mid run leaves a workspace asking to be set up, not one that failed")
    func interruptedRun() {
        var subject = workspace(.running, log: "installing")
        #expect(subject.apply(.runInterrupted) == .moves(to: .pending))
        #expect(subject.setupState == .pending)
        #expect(subject.setupLog.hasPrefix("installing\n[unifieddev] The app stopped"))
    }

    @Test("there is nothing to interrupt outside a run", arguments: [
        SetupState.pending, .succeeded, .failed, .skipped,
    ])
    func interruptingNothing(from state: SetupState) {
        #expect(state.transition(on: .runInterrupted) == .refused)
    }

    @Test("a rebuilt worktree is never refused, from any state", arguments: SetupState.allCases)
    func rebuildIsAlwaysLegal(from state: SetupState) {
        #expect(state.transition(on: .worktreeRebuilt(hasSetupScript: true)).isRefused == false)
        #expect(state.transition(on: .worktreeRebuilt(hasSetupScript: false)).isRefused == false)
    }

    @Test("a restored workspace can no longer claim its setup script has already run")
    func restoreCannotKeepSucceeded() {
        var subject = workspace(.succeeded, log: "installed 400 packages")
        subject.state = .archived
        subject.archivedAt = Date()

        subject.restore(to: "/tmp/w2", hasSetupScript: true)

        #expect(subject.setupState == .pending)
        #expect(subject.setupLog.contains("Run setup again"))
        #expect(subject.state == .active)
        #expect(subject.archivedAt == nil)
        #expect(subject.path == "/tmp/w2")
    }

    @Test("a restored workspace in a project with no setup script has nothing to run")
    func restoreWithNoScript() {
        var subject = workspace(.succeeded)
        subject.restore(to: "/tmp/w2", hasSetupScript: false)
        #expect(subject.setupState == .skipped)
    }

    @Test("a superseded run can no longer report its outcome over the run that replaced it")
    func supersededRunCannotReport() {
        var subject = workspace(.running, log: "second run, still going")

        var superseded = subject
        superseded.setupState = .pending
        #expect(superseded.apply(.runFinished(succeeded: true, log: "first run")) == .refused)
        #expect(superseded.setupState == .pending)
        #expect(superseded.setupLog == "second run, still going")

        #expect(subject.apply(.runFinished(succeeded: true, log: "done")) == .moves(to: .succeeded))
        #expect(subject.setupLog == "done")
    }

    @Test("an outcome cannot be filed without the output that justifies it")
    func outcomeCarriesItsLog() {
        var subject = workspace(.running)
        subject.apply(.runFinished(succeeded: false, log: "composer: command not found"))
        #expect(subject.setupState == .failed)
        #expect(subject.setupLog == "composer: command not found")
    }

    @Test("a long log is capped by the write rather than by whoever remembered to")
    func logIsCapped() {
        var subject = workspace(.running)
        let huge = String(repeating: "x", count: Workspace.setupLogLimit + 5_000)
        subject.apply(.runFinished(succeeded: true, log: huge))
        #expect(subject.setupLog.count == Workspace.setupLogLimit)
    }

    @Test("archiving cannot record the state without the date")
    func archiveWritesBothColumns() {
        var subject = workspace(.succeeded)
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        subject.archive(at: at)
        #expect(subject.state == .archived)
        #expect(subject.archivedAt == at)
    }
}

@Suite("Refused transitions are recorded", .serialized)
struct RefusedTransitionsTests {
    @Test("a refusal leaves the state alone and says so")
    func refusalIsRecorded() {
        RefusedTransitions.forget()
        var subject = Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: .succeeded
        )

        #expect(subject.apply(.runInterrupted) == .refused)

        #expect(subject.setupState == .succeeded)
        #expect(RefusedTransitions.count == 1)
        #expect(RefusedTransitions.recent.last?.sentence == "setup refused runInterrupted from succeeded")
        RefusedTransitions.forget()
    }

    @Test("the list is bounded and the count is not")
    func registerIsBounded() {
        RefusedTransitions.forget()
        var subject = Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            setupState: .succeeded
        )
        for _ in 0..<250 { subject.apply(.runInterrupted) }
        #expect(RefusedTransitions.count == 250)
        #expect(RefusedTransitions.recent.count == 200)
        RefusedTransitions.forget()
    }
}
