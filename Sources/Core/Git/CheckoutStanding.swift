import Foundation

public enum CheckoutStanding: Sendable, Equatable {
    case missing
    case notACheckout
    case noCommitsYet
    case branchMissing(String)
    case fine

    public static func of(_ path: String, branch: String? = nil) async -> CheckoutStanding {
        guard FileManager.default.fileExists(atPath: path) else { return .missing }
        guard await Git.isRepository(path) else { return .notACheckout }
        guard await Git.hasCommits(in: path) else { return .noCommitsYet }
        if let branch, !(await Git.branchExists(branch, in: path)) { return .branchMissing(branch) }
        return .fine
    }

    public static func complaint(about error: any Error) -> String {
        guard let shell = error as? ShellError else { return error.readableMessage }
        let stderr = shell.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stderr.isEmpty else { return "git exited \(shell.status) without saying why." }
        return stderr.hasSuffix(".") ? stderr : stderr + "."
    }
}
