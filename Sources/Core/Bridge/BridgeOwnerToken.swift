import Foundation

public struct BridgeOwnerToken: Sendable {
    public let path: String

    private let makeToken: @Sendable () -> String

    public init(
        path: String,
        makeToken: @escaping @Sendable () -> String = BridgeRegistry.randomToken
    ) {
        self.path = path
        self.makeToken = makeToken
    }

    public static func beside(databasePath: String) -> BridgeOwnerToken {
        let directory = (databasePath as NSString).deletingLastPathComponent
        return BridgeOwnerToken(
            path: (directory as NSString).appendingPathComponent("bridge-owner-token")
        )
    }

    @discardableResult
    public func load() throws -> String {
        if let stored = try? String(contentsOfFile: path, encoding: .utf8) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return try regenerate()
    }

    @discardableResult
    public func regenerate() throws -> String {
        let token = makeToken()
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try Data(token.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        return token
    }
}
