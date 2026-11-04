import Foundation
@testable import Core

enum SleepDaemonFixture {
    struct Reply: Equatable, Sendable {
        let changed: Bool
        let onMain: Bool
    }

    static func absentService() -> String {
        "io.akira.unifieddev.tests.absent.\(UUID().uuidString)"
    }

    @MainActor
    static func first<Value: Sendable>(
        within seconds: Double = 5,
        _ start: (@escaping @Sendable (Value) -> Void) -> Void
    ) async -> Value? {
        let (stream, continuation) = AsyncStream.makeStream(of: Value?.self)
        start { value in
            continuation.yield(value)
            continuation.finish()
        }
        let deadline = Task {
            try? await Task.sleep(for: .seconds(seconds))
            continuation.yield(nil)
            continuation.finish()
        }
        defer { deadline.cancel() }
        for await value in stream { return value }
        return nil
    }

    @MainActor
    static func eventually(within seconds: Double = 5, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let end = clock.now.advanced(by: .seconds(seconds))
        while clock.now < end {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
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
        SleepDaemonConnection.prepare(NSXPCConnection(listenerEndpoint: listener.endpoint), onInvalidation: onInvalidation)
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
