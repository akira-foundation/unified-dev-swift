import Foundation

@objc public protocol SleepControl {
    func setSleepDisabled(_ disabled: Bool, clientPID: Int32, withReply reply: @escaping (Bool) -> Void)
    func readSleepDisabled(withReply reply: @escaping (Bool) -> Void)
}

public enum SleepDaemonConnection {
    public static let machServiceName = "io.akira.unifieddev.sleep"

    public static func open(
        machServiceName: String = machServiceName,
        options: NSXPCConnection.Options = .privileged,
        onInvalidation: @escaping @Sendable () -> Void
    ) -> NSXPCConnection {
        prepare(NSXPCConnection(machServiceName: machServiceName, options: options), onInvalidation: onInvalidation)
    }

    public static func prepare(
        _ connection: NSXPCConnection,
        onInvalidation: @escaping @Sendable () -> Void
    ) -> NSXPCConnection {
        connection.remoteObjectInterface = NSXPCInterface(with: SleepControl.self)
        connection.invalidationHandler = onInvalidation
        connection.resume()
        return connection
    }

    public static func setSleepDisabled(
        _ disabled: Bool,
        clientPID: Int32,
        over connection: NSXPCConnection,
        reply: @escaping @Sendable (Bool) -> Void
    ) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in reply(false) } as? SleepControl
        guard let proxy else {
            reply(false)
            return
        }
        proxy.setSleepDisabled(disabled, clientPID: clientPID) { changed in reply(changed) }
    }
}
