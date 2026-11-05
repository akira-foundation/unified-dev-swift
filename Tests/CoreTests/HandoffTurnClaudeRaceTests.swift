import Testing
import Foundation
@testable import Core

private final class DyingProcess: AgentProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private var written: [String] = []
    private var running = true
    private let output: AsyncThrowingStream<String, Error>.Continuation
    private let errors: AsyncStream<String>.Continuation
    private let answer: String?

    let lines: AsyncThrowingStream<String, Error>
    let errorLines: AsyncStream<String>

    init(answer: String?) {
        self.answer = answer
        (lines, output) = AsyncThrowingStream.makeStream(bufferingPolicy: .unbounded)
        (errorLines, errors) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    var stdin: [String] {
        lock.lock(); defer { lock.unlock() }
        return written
    }

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    var exitStatus: Int32 { get async { 0 } }

    func writeLine(_ text: String) {
        lock.lock(); written.append(text); let isFirst = written.count == 1; lock.unlock()
        if isFirst, let answer { output.yield(answer) }
    }

    func closeStdin() {}
    func terminate() {}
    func kill() {}

    func endOutput() {
        lock.lock(); running = false; lock.unlock()
        output.finish()
        errors.finish()
    }
}

private final class DyingProcesses: @unchecked Sendable {
    private let lock = NSLock()
    private var made: [DyingProcess] = []
    private var birth: (@Sendable () -> Void)?
    private var answer: String?

    var all: [DyingProcess] {
        lock.lock(); defer { lock.unlock() }
        return made
    }

    func onNextBirth(answering answer: String? = nil, _ birth: @escaping @Sendable () -> Void) {
        lock.lock(); self.birth = birth; self.answer = answer; lock.unlock()
    }

    var factory: @Sendable (AgentLaunch) -> any AgentProcessing {
        { _ in
            self.lock.lock()
            let process = DyingProcess(answer: self.answer)
            self.made.append(process)
            let birth = self.birth
            self.birth = nil
            self.lock.unlock()
            birth?()
            return process
        }
    }
}

private final class TaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func hold(_ task: Task<Void, Never>) {
        lock.lock(); self.task = task; lock.unlock()
    }

    private var held: Task<Void, Never>? {
        lock.lock(); defer { lock.unlock() }
        return task
    }

    func finish() async {
        await held?.value
    }
}

private let replyLine = #"{"type":"assistant","message":{"model":"opus","role":"assistant","content":[{"type":"text","text":"working"}]}}"#

@Suite("Handoff turn on Claude while a process is replaced", .scratchDirectory)
struct HandoffTurnClaudeRaceTests: HandoffTurnRunnerFixture {
    private struct Stage {
        let store: Store
        let session: Session
        let processes: DyingProcesses
        let runner: AgentRunner
    }

    private func dyingWithStaleRunningState() async throws -> Stage {
        let store = try makeTestStore("handoff-claude-race")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let repo = try await TempRepo()
        let processes = DyingProcesses()
        let runner = AgentRunner(
            workspacePath: repo.path, session: session, store: store, segmentID: try await activeSegmentID(store, session), makeProcess: processes.factory
        )
        try await runner.send("ONE")
        runner.cancelNow()
        await waitUntil("the stop to settle", within: .seconds(2)) {
            await runner.currentSession.state.isMidTurn == false
        }
        let initialized = #"{"type":"system","subtype":"init","session_id":"s","model":"opus","cwd":"/tmp/w","tools":[]}"#
        await runner.ingest(try #require(AgentEvent.decode(line: initialized)))
        #expect(await runner.currentSession.state.isMidTurn)
        return Stage(store: store, session: session, processes: processes, runner: runner)
    }

    private func sendReleasingTheDyingProcess(_ stage: Stage, _ text: String) async throws {
        let sending = Task { try await stage.runner.send(text) }
        try await Task.sleep(for: .milliseconds(100))
        stage.processes.all[0].endOutput()
        try await sending.value
    }

    @Test("a send that finds its process dying is a new turn, and carries the delta to the new process")
    func aSendDuringADyingRunCarriesTheDelta() async throws {
        let stage = try await dyingWithStaleRunningState()
        let before = try await cursor(stage.store, stage.session)

        try await sendReleasingTheDyingProcess(stage, "TWO")

        let sent = try #require(stage.processes.all.last?.stdin.last)
        #expect(stage.processes.all.count == 2)
        #expect(sent.contains("earlier words"))
        #expect(sent.contains("TWO"))
        #expect(try await cursor(stage.store, stage.session) == before)
        stage.runner.terminateNow()
    }

    @Test("a send arriving before a new process has its first line is no steer, and that line carries the delta")
    func aThirdSendIsNotASteerIntoAnUnpromptedProcess() async throws {
        let stage = try await dyingWithStaleRunningState()
        let third = TaskBox()
        let runner = stage.runner
        stage.processes.onNextBirth {
            third.hold(Task {
                do { try await runner.send("THREE") } catch { Issue.record(error) }
            })
        }

        try await sendReleasingTheDyingProcess(stage, "TWO")
        await third.finish()

        let first = try #require(stage.processes.all.last?.stdin.first)
        #expect(first.contains("earlier words"))
        stage.runner.terminateNow()
    }

    @Test("when the new process answers its first line at once, that line had the delta")
    func aReplyToTheFirstLineConfirmsOnlyADeltaItCarried() async throws {
        let stage = try await dyingWithStaleRunningState()
        let third = TaskBox()
        let runner = stage.runner
        let before = try await cursor(stage.store, stage.session)
        stage.processes.onNextBirth(answering: replyLine) {
            third.hold(Task {
                do { try await runner.send("THREE") } catch { Issue.record(error) }
            })
        }

        try await sendReleasingTheDyingProcess(stage, "TWO")
        await third.finish()
        await waitUntil("the reply to be stored", within: .seconds(2)) {
            ((try? await stage.store.messages(sessionID: stage.session.id)) ?? []).contains { $0.kind == .assistantText }
        }

        let first = try #require(stage.processes.all.last?.stdin.first)
        #expect(first.contains("earlier words"))
        await waitUntil("the reply to confirm", within: .seconds(2)) {
            ((try? await stage.store.activeSegment(sessionID: stage.session.id))??.cursorSeq ?? before) > before
        }
        stage.runner.terminateNow()
    }

    @Test("a reply before a new process has its first line confirms nothing")
    func aReplyBeforeTheFirstLineConfirmsNothing() async throws {
        let stage = try await dyingWithStaleRunningState()
        let stray = TaskBox()
        let runner = stage.runner
        let event = try #require(AgentEvent.decode(line: replyLine))
        stage.processes.onNextBirth {
            stray.hold(Task { await runner.ingest(event) })
        }

        try await sendReleasingTheDyingProcess(stage, "TWO")
        await stray.finish()

        let sent = try #require(stage.processes.all.last?.stdin.first)
        #expect(sent.contains("earlier words"))
        stage.runner.terminateNow()
    }
}
