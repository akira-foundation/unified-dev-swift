import Foundation
import Synchronization
@testable import Core

final class ScriptedProbe: AgentProcessing, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let terminations = Mutex(0)

    let lines: AsyncThrowingStream<String, Error>
    let errorLines = AsyncStream<String> { $0.finish() }

    init(printing output: [String]) {
        var out: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream(bufferingPolicy: .unbounded) { out = $0 }
        continuation = out
        for line in output { continuation.yield(line) }
    }

    var terminationCount: Int { terminations.withLock { $0 } }
    var isRunning: Bool { true }
    var exitStatus: Int32 { get async { 0 } }

    func writeLine(_ text: String) {}
    func closeStdin() {}
    func terminate() {
        terminations.withLock { $0 += 1 }
        continuation.finish()
    }
    func kill() { continuation.finish() }
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

func scriptedProbe(
    _ launches: ProbeLaunches,
    timeout: Duration = .seconds(5),
    inherited: [String: String] = [:],
    output: @escaping @Sendable (String) -> [String]
) -> ClaudeAliasProbe {
    ClaudeAliasProbe(
        executable: "claude", cwd: "/tmp", environment: inherited, timeout: timeout,
        makeProcess: { launch in
            let process = ScriptedProbe(printing: output(probedAlias(of: launch)))
            launches.record(launch, process)
            return process
        }
    )
}
