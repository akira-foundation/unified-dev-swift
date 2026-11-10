import Foundation

enum LoopbackListener {
    static func open(backlog: Int32) -> (descriptor: Int32, port: UInt16)? {
        let opened = socket(AF_INET, SOCK_STREAM, 0)
        guard opened >= 0 else { return nil }
        _ = fcntl(opened, F_SETFD, FD_CLOEXEC)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let listening = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                bind(opened, generic, length) == 0
                    && listen(opened, backlog) == 0
                    && getsockname(opened, generic, &length) == 0
            }
        }
        guard listening else {
            close(opened)
            return nil
        }
        return (opened, UInt16(bigEndian: address.sin_port))
    }
}
