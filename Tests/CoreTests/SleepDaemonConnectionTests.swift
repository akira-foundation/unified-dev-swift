import Foundation
import Testing
@testable import Core

@Suite("Sleep daemon connection")
@MainActor
struct SleepDaemonConnectionTests {
    @Test("answers false off the main queue when the daemon cannot be reached, without trapping")
    func unreachableDaemonRepliesFalse() async {
        let connection = SleepDaemonConnection.open(machServiceName: SleepDaemonFixture.absentService(), options: []) {}
        defer { connection.invalidate() }
        let answer = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (SleepDaemonFixture.Reply) -> Void) in
            SleepDaemonConnection.setSleepDisabled(true, clientPID: 1, over: connection) { changed in
                deliver(.init(changed: changed, onMain: Thread.isMainThread))
            }
        }
        #expect(answer == SleepDaemonFixture.Reply(changed: false, onMain: false))
    }

    @Test("runs the invalidation handler off the main queue without trapping")
    func invalidationRunsOffTheMainQueue() async {
        let onMain = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (Bool) -> Void) in
            let connection = SleepDaemonConnection.open(machServiceName: SleepDaemonFixture.absentService(), options: []) {
                deliver(Thread.isMainThread)
            }
            connection.invalidate()
        }
        #expect(onMain == false)
    }

    @Test("hands the daemon what was asked and returns what it answered", arguments: [true, false])
    func forwardsTheRequestAndTheAnswer(disabled: Bool) async {
        let daemon = FakeSleepDaemon(answer: !disabled)
        let connection = daemon.connect()
        defer { daemon.stop() }
        let answer = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (Bool) -> Void) in
            SleepDaemonConnection.setSleepDisabled(disabled, clientPID: 4242, over: connection, reply: deliver)
        }
        #expect(answer == !disabled)
        #expect(daemon.requests == [FakeSleepDaemon.Request(disabled: disabled, clientPID: 4242)])
    }

    @Test("keeps one connection across requests")
    func reusesTheConnection() async {
        let daemon = FakeSleepDaemon(answer: true)
        defer { daemon.stop() }
        var made = 0
        let client = SleepDaemonClient { onInvalidation in
            made += 1
            return daemon.connect(onInvalidation: onInvalidation)
        }
        let asked = [FakeSleepDaemon.Request(disabled: true, clientPID: 7), .init(disabled: false, clientPID: 8)]
        for request in asked {
            _ = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (Bool) -> Void) in
                client.setSleepDisabled(request.disabled, clientPID: request.clientPID, reply: deliver)
            }
        }
        #expect(made == 1)
        #expect(daemon.requests == asked)
    }

    @Test("forgets a connection once it is invalidated, and opens a new one for the next request")
    func reconnectsAfterInvalidation() async throws {
        let daemon = FakeSleepDaemon(answer: true)
        defer { daemon.stop() }
        var opened: [NSXPCConnection] = []
        let client = SleepDaemonClient { onInvalidation in
            let connection = daemon.connect(onInvalidation: onInvalidation)
            opened.append(connection)
            return connection
        }
        _ = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (Bool) -> Void) in
            client.setSleepDisabled(true, clientPID: 7, reply: deliver)
        }
        try #require(opened.count == 1)
        opened[0].invalidate()
        let forgotten = await SleepDaemonFixture.eventually { !client.isConnected }
        #expect(forgotten)
        let answer = await SleepDaemonFixture.first { (deliver: @escaping @Sendable (Bool) -> Void) in
            client.setSleepDisabled(false, clientPID: 7, reply: deliver)
        }
        #expect(answer == true)
        #expect(opened.count == 2)
    }
}
