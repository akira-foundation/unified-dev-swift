import Foundation

public enum GitRepositoryAnswer: Sendable, Equatable {
    case repository
    case notARepository
    case problem(GitRepositoryProblem)
}

public enum GitRepositoryProblem: Sendable, Equatable {
    case gitUnusable(detail: String)
    case unsafeOwnership(path: String)
    case failed(detail: String)
}

public extension GitRepositoryAnswer {
    static func from(status: Int32, stdout: String, stderr: String, path: String) -> GitRepositoryAnswer {
        let output = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == 0 {
            return output == "true" ? .repository : .notARepository
        }

        let text = stderr.isEmpty ? stdout : stderr
        if text.contains("dubious ownership") {
            return .problem(.unsafeOwnership(path: Self.ownershipPath(in: text) ?? path))
        }
        if text.contains("xcrun: error") || text.contains("developer tools")
            || text.contains("xcode-select") {
            return .problem(.gitUnusable(detail: Self.firstLine(of: text)))
        }
        if text.contains("not a git repository") { return .notARepository }
        return .problem(.failed(detail: Self.firstLine(of: text)))
    }

    static func from(launchFailure error: Error) -> GitRepositoryAnswer {
        if let shell = error as? ShellError, shell.status == 127 {
            return .problem(.gitUnusable(detail: shell.stderr))
        }
        return .problem(.failed(detail: error.readableMessage))
    }

    var problem: GitRepositoryProblem? {
        guard case .problem(let problem) = self else { return nil }
        return problem
    }

    private static func ownershipPath(in text: String) -> String? {
        guard let start = text.range(of: "repository at '") else { return nil }
        let rest = text[start.upperBound...]
        guard let end = rest.firstIndex(of: "'") else { return nil }
        let path = String(rest[..<end])
        return path.isEmpty ? nil : path
    }

    private static func firstLine(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "git exited without saying why"
        return String(line.prefix(300))
    }
}

public extension GitRepositoryProblem {
    var sentence: String {
        switch self {
        case .gitUnusable(let detail):
            """
            Unified Dev could not run git, so it cannot read this folder. git said: \(detail). On a Mac \
            without Apple's command line tools, running xcode-select --install in Terminal fixes \
            this.
            """
        case .unsafeOwnership(let path):
            """
            \(path) belongs to a different user account, so git refuses to work in it. Make your \
            account the owner of the folder, or trust it by running \
            git config --global --add safe.directory '\(path)' in Terminal.
            """
        case .failed(let detail):
            "git could not read this folder. It said: \(detail)"
        }
    }

    var agentSentence: String {
        switch self {
        case .gitUnusable(let detail):
            """
            Unified Dev will not add that folder as a project because git does not run on this Mac \
            (\(detail)). Retrying will not help. Tell the owner, who may need to install Apple's \
            command line tools.
            """
        case .unsafeOwnership(let path):
            """
            Unified Dev will not add \(path) as a project because it belongs to a different user \
            account and git refuses to work in it. Retrying will not help, and do not change git's \
            safe.directory setting yourself: trusting a folder is the owner's decision. Tell them.
            """
        case .failed(let detail):
            """
            Unified Dev will not add that folder as a project because git could not read it (\(detail)). \
            Retrying will not help. Tell the owner, and do not run git init to get past it.
            """
        }
    }
}
