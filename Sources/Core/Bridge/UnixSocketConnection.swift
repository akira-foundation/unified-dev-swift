import Foundation
import Synchronization

public final class UnixSocketConnection: Sendable {
    private let descriptor: Int32
    private let handle: FileHandle
    private let buffer = LineBuffer()
    private let closed = Mutex(false)

    public let lines: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init(descriptor: Int32) {
        self.descriptor = descriptor
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        (lines, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .unbounded)

        var on: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) & ~O_NONBLOCK)

        handle.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty {
                close()
                return
            }
            deliver(data)
        }
    }

    public static func connect(to path: String) throws -> UnixSocketConnection {
        var address = try UnixSocketAddress.make(path: path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw UnixSocketError.couldNotOpen(code: errno) }

        let result = UnixSocketAddress.withSocketAddress(&address) { socketAddress, length in
            Darwin.connect(descriptor, socketAddress, length)
        }
        guard result == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw UnixSocketError.couldNotConnect(path: path, code: code)
        }
        return UnixSocketConnection(descriptor: descriptor)
    }

    public var peerProcessID: pid_t? {
        closed.withLock { closed -> pid_t? in
            guard !closed else { return nil }
            var pid: pid_t = 0
            var length = socklen_t(MemoryLayout<pid_t>.size)
            guard getsockopt(descriptor, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0, pid > 0 else {
                return nil
            }
            return pid
        }
    }

    private func deliver(_ data: Data) {
        for line in buffer.take(data) { continuation.yield(line) }
    }

    public func writeLine(_ text: String) {
        var payload = Array(text.utf8)
        if payload.last != UInt8(ascii: "\n") { payload.append(UInt8(ascii: "\n")) }

        closed.withLock { closed in
            guard !closed else { return }
            var offset = 0
            while offset < payload.count {
                let written = payload.withUnsafeBufferPointer { bytes in
                    Darwin.write(descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                }
                if written < 0 {
                    if errno == EINTR { continue }
                    return
                }
                offset += written
            }
        }
    }

    public func close() {
        let claimed = closed.withLock { closed -> Bool in
            if closed { return false }
            closed = true
            return true
        }
        guard claimed else { return }

        handle.readabilityHandler = nil
        continuation.finish()
        Darwin.close(descriptor)
    }
}
