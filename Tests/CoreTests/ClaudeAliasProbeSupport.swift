import Foundation
import Synchronization
@testable import Core

final class ScriptedProbe: AgentProcessing, @unchecked Sendable {
    private struct State {
        var terminations = 0
        var kills = 0
        var exited = false
        var waiting: [CheckedContinuation<Int32, Never>] = []
    }

    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let state = Mutex(State())
    private let ignoresTerminate: Bool

    let lines: AsyncThrowingStream<String, Error>
    let errorLines = AsyncStream<String> { $0.finish() }

    init(printing output: [String], ignoresTerminate: Bool = false) {
        self.ignoresTerminate = ignoresTerminate
        var out: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream(bufferingPolicy: .unbounded) { out = $0 }
        continuation = out
        for line in output { continuation.yield(line) }
    }

    var terminationCount: Int { state.withLock { $0.terminations } }
    var killCount: Int { state.withLock { $0.kills } }
    var isRunning: Bool { state.withLock { !$0.exited } }
    var exitStatus: Int32 {
        get async {
            await withCheckedContinuation { continuation in
                let exited = state.withLock { state -> Bool in
                    if !state.exited { state.waiting.append(continuation) }
                    return state.exited
                }
                if exited { continuation.resume(returning: 0) }
            }
        }
    }

    func writeLine(_ text: String) {}
    func closeStdin() {}
    func terminate() {
        state.withLock { $0.terminations += 1 }
        guard !ignoresTerminate else { return }
        exit()
    }

    func kill() {
        state.withLock { $0.kills += 1 }
        exit()
    }

    private func exit() {
        continuation.finish()
        let waiting = state.withLock { state -> [CheckedContinuation<Int32, Never>] in
            state.exited = true
            defer { state.waiting = [] }
            return state.waiting
        }
        for waiter in waiting { waiter.resume(returning: 0) }
    }
}

final class ProbeLaunches: @unchecked Sendable {
    private let state = Mutex<[(AgentLaunch, ScriptedProbe)]>([])

    var launches: [AgentLaunch] { state.withLock { $0.map(\.0) } }
    var processes: [ScriptedProbe] { state.withLock { $0.map(\.1) } }

    func record(_ launch: AgentLaunch, _ process: ScriptedProbe) {
        state.withLock { $0.append((launch, process)) }
    }
}

func probeInitLine(_ model: String) -> String {
    #"{"type":"system","subtype":"init","session_id":"s","cwd":"/tmp","model":"\#(model)"}"#
}

func probedAlias(of launch: AgentLaunch) -> String {
    guard let index = launch.arguments.firstIndex(of: "--model") else { return "" }
    return launch.arguments[index + 1]
}

func probeAccount(_ name: String = "work") -> AgentAccountHome {
    let directory = URL(filePath: TestScratch.path("accounts/\(name)"), directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return AgentAccountHome(provider: .claudeCode, id: AgentAccountID(name), directory: directory, isDefault: false)
}

func unmanaged() -> ClaudeManagedSettings {
    ClaudeManagedSettings(
        root: URL(filePath: TestScratch.path("managed/root"), directoryHint: .isDirectory),
        preferences: URL(filePath: TestScratch.path("managed/preferences"), directoryHint: .isDirectory),
        user: "tester"
    )
}

func probeWorkRoot() -> String {
    let root = TestScratch.path("probe-work")
    try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    return root
}

func scriptedProbe(
    _ launches: ProbeLaunches,
    timeout: Duration = .seconds(5),
    exitGrace: Duration = .milliseconds(100),
    inherited: [String: String] = [:],
    managed: ClaudeManagedSettings? = nil,
    activity: ClaudeAccountActivity = ClaudeAccountActivity(),
    ignoresTerminate: Bool = false,
    output: @escaping @Sendable (String) -> [String]
) -> ClaudeAliasProbe {
    ClaudeAliasProbe(
        executable: "claude", workRoot: probeWorkRoot(), environment: inherited, timeout: timeout,
        exitGrace: exitGrace, managed: managed ?? unmanaged(), activity: activity,
        makeProcess: { launch in
            let process = ScriptedProbe(printing: output(probedAlias(of: launch)), ignoresTerminate: ignoresTerminate)
            launches.record(launch, process)
            return process
        }
    )
}

final class AwaitedAnswer<Value: Sendable>: Sendable {
    private let value = Mutex<Value?>(nil)

    func set(_ answer: Value) { value.withLock { $0 = answer } }
    var answer: Value? { value.withLock { $0 } }

    func wait(upTo deadline: Duration) async -> Value? {
        let end = ContinuousClock.now + deadline
        while ContinuousClock.now < end {
            if let answer { return answer }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return answer
    }
}
