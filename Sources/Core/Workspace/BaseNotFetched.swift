import Foundation

public struct BaseNotFetched: Error, Sendable, Equatable, CustomStringConvertible {
    public let branch: String
    public let remote: String

    public init(branch: String, remote: String) {
        self.branch = branch
        self.remote = remote
    }

    static func check(fetched: Bool, acceptsStaleBase: Bool, branch: String, remote: String) throws {
        guard !fetched, !acceptsStaleBase else { return }
        throw BaseNotFetched(branch: branch, remote: remote)
    }

    public var description: String {
        "Unified Dev could not fetch '\(branch)' from \(remote), so \(remote)/\(branch) on this Mac may be behind."
    }

    public var sentence: String {
        """
        Unified Dev could not fetch '\(branch)' from \(remote), so the copy of it on this Mac may be \
        behind what \(remote) has. Nothing has been created.

        Press Return to try once more. If \(remote) still does not answer, the workspace starts from \
        '\(remote)/\(branch)' as this Mac last saw it.
        """
    }
}
