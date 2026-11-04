import Foundation
import Testing
@testable import Core

@Suite("Sleep daemon connection")
@MainActor
struct SleepDaemonConnectionTests {
    private static func unreachableService() -> String {
        "io.akira.unifieddev.tests.absent.\(UUID().uuidString)"
    }

    @Test("answers false off the main queue when the daemon cannot be reached, without trapping")
    func unreachableDaemonRepliesFalse() async {
        let connection = SleepDaemonConnection.open(machServiceName: Self.unreachableService(), options: []) {}
        defer { connection.invalidate() }
        let answer = await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, Bool), Never>) in
            SleepDaemonConnection.setSleepDisabled(true, clientPID: 1, over: connection) { changed in
                continuation.resume(returning: (changed, Thread.isMainThread))
            }
        }
        #expect(answer.0 == false)
        #expect(answer.1 == false)
    }

    @Test("runs the invalidation handler off the main queue without trapping")
    func invalidationRunsOffTheMainQueue() async {
        let onMain = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let connection = SleepDaemonConnection.open(machServiceName: Self.unreachableService(), options: []) {
                continuation.resume(returning: Thread.isMainThread)
            }
            connection.invalidate()
        }
        #expect(onMain == false)
    }
}
