import Foundation

public final class RefusingEndpoint: Sendable {
    public let port: UInt16
    private let source: any DispatchSourceRead

    public init?() {
        guard let listener = LoopbackListener.open(backlog: 64) else { return nil }
        let opened = listener.descriptor
        _ = fcntl(opened, F_SETFL, fcntl(opened, F_GETFL) | O_NONBLOCK)
        port = listener.port
        source = DispatchSource.makeReadSource(fileDescriptor: opened, queue: .global(qos: .utility))
        source.setEventHandler { Self.resetWaiting(on: opened) }
        source.setCancelHandler { close(opened) }
        source.resume()
    }

    public var url: String { "http://127.0.0.1:\(port)" }

    deinit { source.cancel() }

    private static func resetWaiting(on listener: Int32) {
        while true {
            let accepted = accept(listener, nil, nil)
            guard accepted >= 0 else { return }
            var reset = linger(l_onoff: 1, l_linger: 0)
            setsockopt(accepted, SOL_SOCKET, SO_LINGER, &reset, socklen_t(MemoryLayout<linger>.size))
            close(accepted)
        }
    }
}
