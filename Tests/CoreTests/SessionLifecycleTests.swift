import Foundation
import Testing
@testable import Core

@Suite("The session lifecycle")
struct SessionLifecycleTests {
    private func session(_ state: SessionState) -> Session {
        Session(workspaceID: WorkspaceID("w"), state: state)
    }

    @Test("a turn starts from every state with no turn open", arguments: [
        SessionState.idle, .failed, .cancelled,
    ])
    func turnStarts(from state: SessionState) {
        #expect(state.transition(on: .turnStarted) == .moves(to: .running))
    }

    @Test("a turn cannot be started while the agent is waiting on an answer")
    func turnCannotStartWhileWaiting() {
        #expect(SessionState.waiting.transition(on: .turnStarted) == .refused)
        #expect(SessionState.running.transition(on: .turnStarted) == .unchanged)
    }

    @Test("a turn in flight ends where the result says")
    func turnFinishes() {
        for state in [SessionState.running, .waiting] {
            #expect(state.transition(on: .turnFinished(isError: false)) == .moves(to: .idle))
            #expect(state.transition(on: .turnFinished(isError: true)) == .moves(to: .failed))
        }
    }

    @Test("a result for a turn that is already closed is ignored, not refused", arguments: [
        SessionState.idle, .failed, .cancelled,
    ])
    func lateResult(from state: SessionState) {
        #expect(state.transition(on: .turnFinished(isError: false)) == .unchanged)
        #expect(state.transition(on: .turnFinished(isError: true)) == .unchanged)
    }

    @Test("answering when nothing is blocked does nothing and is never refused", arguments: [
        SessionState.idle, .running, .failed, .cancelled,
    ])
    func unblockingNothing(from state: SessionState) {
        #expect(state.transition(on: .unblocked) == .unchanged)
    }

    @Test("answering the last question puts the turn back to work")
    func unblocking() {
        #expect(SessionState.waiting.transition(on: .unblocked) == .moves(to: .running))
    }

    @Test("a process that ends says which of the two things happened")
    func processEnds() {
        for state in [SessionState.running, .waiting] {
            #expect(state.transition(on: .processExited) == .moves(to: .idle))
            #expect(state.transition(on: .processFailed) == .moves(to: .failed))
        }
        for state in [SessionState.idle, .failed, .cancelled] {
            #expect(state.transition(on: .processExited) == .unchanged)
            #expect(state.transition(on: .processFailed) == .unchanged)
        }
    }

    @Test("nothing the last launch left mid turn is mid turn after a relaunch", arguments: [
        SessionState.running, .waiting,
    ])
    func relaunchClearsMidTurn(from state: SessionState) {
        #expect(state.transition(on: .appRelaunched) == .moves(to: .idle))
    }

    @Test("a relaunch is never refused, from any state", arguments: SessionState.allCases)
    func relaunchIsAlwaysLegal(from state: SessionState) {
        #expect(state.transition(on: .appRelaunched).isRefused == false)
    }

    @Test("a settled question can no longer mark a session as waiting", arguments: [
        SessionState.idle, .failed, .cancelled,
    ])
    func blockedOnASettledQuestion(from state: SessionState) {
        var subject = session(state)
        #expect(subject.apply(.blocked) == .refused)
        #expect(subject.state == state)
    }

    @Test("a question during a turn is what waiting means")
    func blockedDuringATurn() {
        #expect(SessionState.running.transition(on: .blocked) == .moves(to: .waiting))
        #expect(SessionState.waiting.transition(on: .blocked) == .unchanged)
    }

    @Test("stopping a turn that is not running can no longer rewrite how it ended", arguments: [
        SessionState.idle, .failed,
    ])
    func cancellingNothing(from state: SessionState) {
        var subject = session(state)
        #expect(subject.apply(.cancelled) == .refused)
        #expect(subject.state == state)
    }

    @Test("stopping a turn that is running or blocked is what cancelling means")
    func cancelling() {
        for state in [SessionState.running, .waiting] {
            #expect(state.transition(on: .cancelled) == .moves(to: .cancelled))
        }
        #expect(SessionState.cancelled.transition(on: .cancelled) == .unchanged)
    }

    @Test("a state that moves always stamps when it moved")
    func moveStampsTheMoment() {
        var subject = session(.idle)
        subject.updatedAt = Date(timeIntervalSince1970: 0)
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        subject.apply(.turnStarted, at: at)
        #expect(subject.state == .running)
        #expect(subject.updatedAt == at)
    }

    @Test("a state that does not move leaves the clock alone")
    func stillnessDoesNotStampTheMoment() {
        var subject = session(.idle)
        let before = Date(timeIntervalSince1970: 0)
        subject.updatedAt = before

        subject.apply(.blocked, at: Date())
        subject.apply(.unblocked, at: Date())
        #expect(subject.updatedAt == before)
    }
}
