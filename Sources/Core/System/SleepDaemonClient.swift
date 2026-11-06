import Foundation

@MainActor
public final class SleepDaemonClient {
    public typealias ConnectionMaker = @MainActor (@escaping @Sendable () -> Void) -> NSXPCConnection

    private let makeConnection: ConnectionMaker
    private var connection: NSXPCConnection?

    public init(makeConnection: @escaping ConnectionMaker = { SleepDaemonConnection.open(onInvalidation: $0) }) {
        self.makeConnection = makeConnection
    }

    public var isConnected: Bool { connection != nil }

    public func setSleepDisabled(
        _ disabled: Bool,
        clientPID: Int32,
        reply: @escaping @Sendable (Bool) -> Void = { _ in }
    ) {
        SleepDaemonConnection.setSleepDisabled(disabled, clientPID: clientPID, over: liveConnection(), reply: reply)
    }

    private func liveConnection() -> NSXPCConnection {
        if let connection { return connection }
        let created = makeConnection { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection = created
        return created
    }
}
