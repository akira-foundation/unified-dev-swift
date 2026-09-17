import Foundation
import Testing
@testable import Core

@Suite("Concurrency safety")
struct ConcurrencySafetyTests {
    @Test("a satisfied condition is observed even at the polling deadline")
    func observesConditionAtDeadline() async throws {
        try await waitUntil({ true }, timeout: .zero)
    }

    @Test("an unsatisfied polling deadline stops the test")
    func rejectsUnsatisfiedCondition() async {
        await #expect(throws: ConditionTimeout.self) {
            try await waitUntil({ false }, timeout: .zero)
        }
    }

    @Test("keeps every line a process wrote just before it exited", .timeLimit(.minutes(1)))
    func doesNotTruncateOutputWrittenBeforeExit() async throws {
        let count = 20_000
        let process = StreamingProcess(
            executable: "/bin/zsh",
            arguments: ["-c", "for i in $(seq 1 \(count)); do print -r -- line-$i; done"]
        )

        var seen = 0
        var outOfOrder: String?
        for try await line in process.lines where line.hasPrefix("line-") {
            seen += 1
            if outOfOrder == nil, line != "line-\(seen)" {
                outOfOrder = "expected line-\(seen), got \(line)"
            }
        }

        #expect(seen == count)
        #expect(outOfOrder == nil, "\(outOfOrder ?? "")")
        #expect(await process.exitStatus == 0)
    }

    @Test("finishes even when a grandchild keeps the pipe open", .timeLimit(.minutes(1)))
    func finishesWhenAnOrphanHoldsStdout() async throws {
        let process = StreamingProcess(
            executable: "/bin/zsh",
            arguments: ["-c", "(sleep 45 &) ; print -r -- done"]
        )

        var lines: [String] = []
        for try await line in process.lines { lines.append(line) }

        #expect(lines.contains("done"))
        _ = await process.exitStatus
        process.kill()
    }

    @Test("a launch failure reaches a consumer that subscribes afterwards", .timeLimit(.minutes(1)))
    func aFailedStartStillFinishesTheStream() async throws {
        let process = StreamingProcess(
            executable: "unifieddev-definitely-not-on-path",
            arguments: []
        )

        #expect(throws: (any Error).self) { try process.start() }

        var failed = false
        do {
            for try await _ in process.lines {}
        } catch {
            failed = true
        }

        #expect(failed)
        #expect(await process.exitStatus == 127)
    }

    @Test("a cancelled task does not get a subprocess spawned for it")
    func shellRefusesToSpawnForACancelledTask() async {
        let task = Task { () -> ShellResult in
            while !Task.isCancelled { await Task.yield() }
            return try await Shell.run("/bin/echo", ["hi"])
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("a finishing run cannot file the turn that replaced it as done", .timeLimit(.minutes(1)))
    func aStaleRunDoesNotOverwriteTheNextTurn() async throws {
        let store = try Store.inMemory()
        let repo = Repo(name: "repo", path: "/tmp/repo")
        try await store.upsert(repo)
        let workspace = Workspace(
            repoID: repo.id, name: "ws", branch: "b", path: "/tmp/ws", baseBranch: "main"
        )
        try await store.upsert(workspace)
        let session = Session(workspaceID: workspace.id, title: "t")
        try await store.upsert(session)

        let first = ScriptedProcess()
        let second = ScriptedProcess()
        let factory = ProcessFactory(processes: [first, second])

        let runner = AgentRunner(
            workspacePath: "/tmp",
            session: session,
            store: store,
            makeProcess: { _ in factory.next() }
        )

        try await runner.send("one")

        first.finishLines()
        try await waitUntil { await runner.isRunning == false }

        try await runner.send("two")
        #expect(await runner.currentSession.state == .running)

        first.finishErrors()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await runner.currentSession.state == .running)

        second.finishLines()
        second.finishErrors()
    }
}

private final class ProcessFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: [ScriptedProcess]

    init(processes: [ScriptedProcess]) {
        remaining = processes
    }

    func next() -> any AgentProcessing {
        lock.lock(); defer { lock.unlock() }
        return remaining.isEmpty ? ScriptedProcess() : remaining.removeFirst()
    }
}

private final class ScriptedProcess: AgentProcessing, @unchecked Sendable {
    let lines: AsyncThrowingStream<String, Error>
    let errorLines: AsyncStream<String>

    private let linesContinuation: AsyncThrowingStream<String, Error>.Continuation
    private let errorContinuation: AsyncStream<String>.Continuation
    private let state = NSLock()
    private var running = true

    init() {
        (lines, linesContinuation) = AsyncThrowingStream.makeStream(of: String.self, throwing: Error.self)
        (errorLines, errorContinuation) = AsyncStream.makeStream(of: String.self)
    }

    var isRunning: Bool {
        state.lock(); defer { state.unlock() }
        return running
    }

    var exitStatus: Int32 { get async { 0 } }

    func finishLines() {
        state.lock(); running = false; state.unlock()
        linesContinuation.finish()
    }

    func finishErrors() {
        errorContinuation.finish()
    }

    func writeLine(_ text: String) {}
    func closeStdin() {}
    func terminate() { finishLines() }
    func kill() { finishLines() }
}

private func waitUntil(
    _ condition: @Sendable () async -> Bool,
    timeout: Duration = .seconds(5)
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while true {
        if await condition() { return }
        guard ContinuousClock.now < deadline else { throw ConditionTimeout() }
        try await Task.sleep(for: .milliseconds(5))
    }
}

private struct ConditionTimeout: Error {}

@Suite("Agent catalog caching")
struct AgentCatalogCachingTests {
    @Test("concurrent callers share one detection per agent", .timeLimit(.minutes(1)))
    func concurrentCallersDoNotDetectTwice() async {
        let catalog = AgentCatalog()

        async let first = catalog.statuses()
        async let second = catalog.statuses()
        async let third = catalog.status(for: .claudeCode)

        let (one, two, single) = await (first, second, third)

        #expect(one == two)
        #expect(one.contains { $0.kind == single.kind && $0.connection == single.connection })
        #expect(await catalog.detectionCount == AgentKind.allCases.count)
    }

    @Test("a refresh does not file an answer gathered before it", .timeLimit(.minutes(1)))
    func invalidateDiscardsADetectionAlreadyInFlight() async {
        let catalog = AgentCatalog()
        _ = await catalog.statuses()
        await catalog.invalidate()
        let after = await catalog.statuses()
        #expect(after.count == AgentKind.allCases.count)
    }
}
