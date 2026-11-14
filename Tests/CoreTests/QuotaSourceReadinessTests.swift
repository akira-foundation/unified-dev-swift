import Foundation
import Synchronization
import Testing
@testable import Core

final class QuotaReadinessRecorder: Sendable {
    private let answered = Mutex(0)
    private let seenAtSpawn = Mutex<[Int]>([])

    var wait: @Sendable () async -> Void {
        { [self] in
            await Task.yield()
            answered.withLock { $0 += 1 }
        }
    }

    var factory: @Sendable (AgentLaunch) -> any AgentProcessing {
        { [self] _ in
            let count = answered.withLock { $0 }
            seenAtSpawn.withLock { $0.append(count) }
            return SilentProcess()
        }
    }

    var answers: Int { answered.withLock { $0 } }

    var spawns: [Int] { seenAtSpawn.withLock { $0 } }
}

@Suite("The quota sources wait for the login shell they are handed")
struct QuotaSourceReadinessTests {
    enum Provider: String, CaseIterable, Sendable {
        case claudeCode, codex

        func source(_ readiness: QuotaReadinessRecorder, executable: String = "/bin/sh") -> any AgentQuotaSource {
            switch self {
            case .claudeCode:
                ClaudeCodeQuotaSource(
                    executable: executable, environment: [:], accountPath: "/nonexistent/claude.json",
                    makeProcess: readiness.factory, loginShellReady: readiness.wait
                )
            case .codex:
                CodexQuotaSource(
                    executable: executable, environment: [:],
                    makeProcess: readiness.factory, loginShellReady: readiness.wait
                )
            }
        }
    }

    @Test("a read asks the agent only once the readiness it was handed has answered", arguments: Provider.allCases)
    func readWaits(provider: Provider) async {
        let readiness = QuotaReadinessRecorder()

        _ = await provider.source(readiness).read()

        #expect(readiness.spawns == [1])
    }

    @Test("the standing waits for the readiness it was handed", arguments: Provider.allCases)
    func standingWaits(provider: Provider) async {
        let readiness = QuotaReadinessRecorder()

        let standing = await provider.source(readiness).standing()

        #expect(readiness.answers == 1)
        #expect(standing.isInstalled)
        #expect(readiness.spawns.isEmpty)
    }
}
