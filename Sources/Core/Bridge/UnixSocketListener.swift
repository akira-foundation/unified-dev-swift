import Foundation
import Synchronization

public final class UnixSocketListener: Sendable {
    public let path: String
    private let descriptor: Int32
    private let source: any DispatchSourceRead
    private let stopped = Mutex(false)

    public init(path: String, accept handler: @escaping @Sendable (UnixSocketConnection) -> Void) throws {
        self.path = path

        var address = try UnixSocketAddress.make(path: path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw UnixSocketError.couldNotOpen(code: errno) }
        self.descriptor = descriptor

        unlink(path)
        let previousMask = umask(0o077)
        let bound = UnixSocketAddress.withSocketAddress(&address) { socketAddress, length in
            bind(descriptor, socketAddress, length)
        }
        umask(previousMask)
        guard bound == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw UnixSocketError.couldNotBind(path: path, code: code)
        }
        guard listen(descriptor, 16) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            unlink(path)
            throw UnixSocketError.couldNotListen(path: path, code: code)
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)

        source = DispatchSource.makeReadSource(
            fileDescriptor: descriptor,
            queue: DispatchQueue(label: "io.akira.unifieddev.bridge.accept")
        )
        source.setEventHandler { [descriptor] in
            while true {
                let accepted = Darwin.accept(descriptor, nil, nil)
                guard accepted >= 0 else { return }
                handler(UnixSocketConnection(descriptor: accepted))
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
    }

    public func stop() {
        let claimed = stopped.withLock { stopped -> Bool in
            if stopped { return false }
            stopped = true
            return true
        }
        guard claimed else { return }

        source.cancel()
        unlink(path)
    }

    deinit {
        stop()
    }
}
