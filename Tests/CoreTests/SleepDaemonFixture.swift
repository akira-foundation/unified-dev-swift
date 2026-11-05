import Foundation
@testable import Core

enum SleepDaemonFixture {
    static let answerTurnLimit = 333

    struct Reply: Equatable, Sendable {
        let changed: Bool
        let onMain: Bool
    }

    static func absentService() -> String {
        "io.akira.unifieddev.tests.absent.\(UUID().uuidString)"
    }

    @MainActor
    static func first<Value: Sendable>(
        withinTurns turns: Int = answerTurnLimit,
        _ start: (@escaping @Sendable (Value) -> Void) -> Void
    ) async -> Value? {
        let (stream, continuation) = AsyncStream.makeStream(of: Value?.self)
        start { value in
            continuation.yield(value)
            continuation.finish()
        }
        let deadline = Task {
            await waitForDispatchTurns(turns)
            continuation.yield(nil)
            continuation.finish()
        }
        defer { deadline.cancel() }
        for await value in stream { return value }
        return nil
    }

    @MainActor
    static func eventually(withinTurns turns: Int = answerTurnLimit, _ condition: () -> Bool) async -> Bool {
        for _ in 0..<turns {
            if condition() { return true }
            await waitForDispatchTurns(1)
        }
        return condition()
    }

    private static func waitForDispatchTurns(_ turns: Int) async {
        for _ in 0..<turns {
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { (turn: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(15)) { turn.resume() }
            }
        }
    }
}

final class FakeSleepDaemon: NSObject, NSXPCListenerDelegate, SleepControl, @unchecked Sendable {
    struct Request: Equatable, Sendable {
        let disabled: Bool
        let clientPID: Int32
    }

    private let answer: Bool
    private let listener = NSXPCListener.anonymous()
    private let lock = NSLock()
    private var recorded: [Request] = []
    private var handedOut: [NSXPCConnection] = []

    init(answer: Bool) {
        self.answer = answer
        super.init()
        listener.delegate = self
        listener.resume()
    }

    var requests: [Request] {
        lock.withLock { recorded }
    }

    func connect(onInvalidation: @escaping @Sendable () -> Void = {}) -> NSXPCConnection {
        let connection = SleepDaemonConnection.prepare(
            NSXPCConnection(listenerEndpoint: listener.endpoint), onInvalidation: onInvalidation
        )
        lock.withLock { handedOut.append(connection) }
        return connection
    }

    func stop() {
        lock.withLock { handedOut }.forEach { $0.invalidate() }
        listener.invalidate()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: SleepControl.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func setSleepDisabled(_ disabled: Bool, clientPID: Int32, withReply reply: @escaping (Bool) -> Void) {
        lock.withLock { recorded.append(Request(disabled: disabled, clientPID: clientPID)) }
        reply(answer)
    }

    func readSleepDisabled(withReply reply: @escaping (Bool) -> Void) {
        reply(answer)
    }
}
