import CryptoKit
import Foundation

enum ClaudeKeychainEntries {
    static let accountFallback = "claude-code-user"

    private static let accountCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    )

    static func of(
        configDirectory path: String, environment: [String: String], username: String
    ) -> [AgentAccountKeychain.Entry] {
        let digest = directoryDigest(path)
        let owner = account(environment: environment, username: username)
        return ["Claude Code-credentials-\(digest)", "Claude Code-\(digest)"].map {
            AgentAccountKeychain.Entry(service: $0, account: owner)
        }
    }

    private static func directoryDigest(_ path: String) -> String {
        let bytes = SHA256.hash(data: Data(path.precomposedStringWithCanonicalMapping.utf8))
        return bytes.map { String(format: "%02x", $0) }.joined().prefix(8).description
    }

    private static func account(environment: [String: String], username: String) -> String {
        let named = environment["USER"].flatMap { $0.isEmpty ? nil : $0 } ?? username
        let isUsable = !named.isEmpty && named.unicodeScalars.allSatisfy(accountCharacters.contains)
        return isUsable ? named : accountFallback
    }
}
