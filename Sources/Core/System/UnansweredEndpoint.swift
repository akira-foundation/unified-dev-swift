import Foundation

public final class UnansweredEndpoint: Sendable {
    public let port: UInt16
    private let descriptor: Int32

    public init?() {
        guard let listener = LoopbackListener.open(backlog: 16) else { return nil }
        descriptor = listener.descriptor
        port = listener.port
    }

    public var url: String { "http://127.0.0.1:\(port)" }

    deinit { close(descriptor) }
}
