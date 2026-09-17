import Foundation

public enum BridgeSocketPath {
    public static let limit = 104

    public static func derive(
        databasePath: String,
        directory: String = NSTemporaryDirectory()
    ) throws -> String {
        let name = "bridge-" + TmuxSessions.fingerprint(databasePath) + ".sock"
        let path = (directory as NSString).appendingPathComponent(name)
        guard path.utf8.count < limit else {
            throw BridgeSocketPathError.tooLong(path: path, limit: limit)
        }
        return path
    }
}

public enum BridgeSocketPathError: Error, CustomStringConvertible {
    case tooLong(path: String, limit: Int)

    public var description: String {
        switch self {
        case .tooLong(let path, let limit):
            """
            the bridge socket path \(path) is \(path.utf8.count) bytes, and a unix socket \
            name may be at most \(limit - 1). A longer one is truncated rather than refused, \
            so two copies of Unified Dev could quietly share one socket
            """
        }
    }
}
