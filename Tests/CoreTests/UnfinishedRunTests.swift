import Testing
import Foundation
@testable import Core

@Suite("UnfinishedRun")
struct UnfinishedRunTests {
    @Test("a clean exit in the middle of a turn is still worth a row")
    func cleanExitMidTurn() throws {
        let run = UnfinishedRun.of(
            status: 0, sawResult: false, state: .running, stderr: "", command: "/usr/bin/claude"
        )

        let unfinished = try #require(run)
        #expect(unfinished.leftATurnOpen)
        #expect(unfinished.wasSilent)
        #expect(unfinished.message == UnfinishedRun.silentSentence)
    }

    @Test("a clean exit with no turn open says nothing")
    func cleanExitBetweenTurns() {
        for state in [SessionState.idle, .failed, .cancelled] {
            #expect(UnfinishedRun.of(
                status: 0, sawResult: true, state: state, stderr: "", command: ""
            ) == nil)
        }
    }

    @Test("a non-zero exit with nothing reported is still a row between turns")
    func failsBetweenTurns() throws {
        let run = UnfinishedRun.of(
            status: 2, sawResult: false, state: .idle, stderr: "error: not logged in", command: "c"
        )

        let unfinished = try #require(run)
        #expect(unfinished.leftATurnOpen == false)
        #expect(unfinished.wasSilent == false)
        #expect(unfinished.message.contains("status 2"))
        #expect(unfinished.message.contains("not logged in"))
    }

    @Test("a stale sawResult cannot silence a turn that is still open")
    func staleSawResult() {
        let run = UnfinishedRun.of(
            status: 0, sawResult: true, state: .running, stderr: "", command: ""
        )

        #expect(run?.leftATurnOpen == true)
    }

    @Test("a turn blocked on a question is abandoned too")
    func waitingIsMidTurn() {
        let run = UnfinishedRun.of(
            status: 0, sawResult: false, state: .waiting, stderr: "", command: ""
        )

        #expect(run?.leftATurnOpen == true)
    }

    @Test("an exit that said something is reported in its own words, not as silence")
    func spokeOnTheWayOut() throws {
        let run = UnfinishedRun.of(
            status: 0, sawResult: false, state: .running,
            stderr: "Error: the weekly limit has been reached", command: ""
        )

        let unfinished = try #require(run)
        #expect(unfinished.wasSilent == false)
        #expect(unfinished.message.contains("weekly limit"))
        #expect(unfinished.subtype == UnfinishedRun.exitSubtype)
    }

    @Test("whitespace on stderr is not something said")
    func blankStderrIsSilence() {
        let run = UnfinishedRun.of(
            status: 0, sawResult: false, state: .running, stderr: "  \n \n", command: ""
        )

        #expect(run?.wasSilent == true)
    }

    @Test("the payload is what AgentExit reads back")
    func payloadRoundTrips() throws {
        let run = try #require(UnfinishedRun.of(
            status: 0, sawResult: false, state: .running, stderr: "", command: "/opt/bin/claude"
        ))

        let exit = AgentExit.decode(run.payload)
        #expect(exit.cause == .endedMidTurn)
        #expect(exit.command == "/opt/bin/claude")
        #expect(exit.title == "Turn never finished")
        #expect(exit.summary.contains("middle of this turn"))
        #expect(exit.advice.contains("still in the worktree"))
        #expect(exit.advice.contains("/opt/bin/claude"))
    }

    @Test("a clean status is never drawn as a clean ending")
    func cleanStatusIsNotACleanEnding() throws {
        let run = try #require(UnfinishedRun.of(
            status: 0, sawResult: false, state: .running, stderr: "", command: ""
        ))

        #expect(AgentExit.decode(run.payload).title.contains("(0)") == false)
    }

    @Test("a run that spoke on the way out keeps the old payload shape")
    func spokenPayloadIsAProcessExit() throws {
        let run = try #require(UnfinishedRun.of(
            status: 1, sawResult: false, state: .running, stderr: "Error: no credentials", command: ""
        ))

        let exit = AgentExit.decode(run.payload)
        #expect(exit.status == 1)
        #expect(exit.cause == .reported("Error: no credentials"))
    }
}
