import Foundation

public enum BranchHolder: Sendable, Hashable, Codable {
    case workspace(String)
    case projectCheckout(path: String)
    case otherWorktree(path: String)

    public var isAppWorkspace: Bool {
        if case .workspace = self { return true }
        return false
    }

    public var note: String {
        switch self {
        case .workspace(let name): "In use by \(name)"
        case .projectCheckout: "Checked out in the project"
        case .otherWorktree: "Checked out elsewhere"
        }
    }

    public var described: String {
        switch self {
        case .workspace(let name): "the workspace '\(name)'"
        case .projectCheckout(let path): "the project's own checkout at \(path)"
        case .otherWorktree(let path): "the worktree at \(path)"
        }
    }

    public var wayOut: String {
        switch self {
        case .workspace: "Go to that workspace to carry on there"
        case .projectCheckout: "Switch the project itself to another branch"
        case .otherWorktree: "Close or remove that worktree to free the branch"
        }
    }

    public func refusal(branch: String) -> String {
        let opening: String
        switch self {
        case .workspace(let name):
            opening = "'\(branch)' is already open in '\(name)'."
        case .projectCheckout(let path):
            opening = "'\(branch)' is the branch the project itself is on, at \(path)."
        case .otherWorktree(let path):
            opening = "'\(branch)' is checked out at \(path), which is not one of Unified Dev's workspaces."
        }
        return opening
            + " Git allows one worktree per branch, so it cannot be opened twice. \(wayOut),"
            + " or start a new branch from '\(branch)' under New branch from,"
            + " which gets you the same code."
    }

    public func agentRefusal(branch: String) -> String {
        let opening: String
        switch self {
        case .workspace(let name):
            opening = "'\(branch)' is already open in Unified Dev's workspace '\(name)'."
        case .projectCheckout(let path):
            opening = "'\(branch)' is the branch the project itself is on, at \(path)."
        case .otherWorktree(let path):
            opening = "'\(branch)' is checked out at \(path), which is not one of Unified Dev's workspaces."
        }
        return opening
            + " Git allows one worktree per branch, so Unified Dev cannot open it again."
            + " Ask again with base_branch '\(branch)' instead of existing_branch, which cuts a"
            + " new branch from it and starts you on the same code, or leave it and say so."
    }
}

public extension BranchHolder {
    static func byBranch(
        worktrees: [WorktreeEntry],
        projectPath: String,
        workspaceNames: [String: String] = [:]
    ) -> [String: BranchHolder] {
        let project = standardised(projectPath)
        var holders: [String: BranchHolder] = [:]
        for entry in worktrees {
            guard !entry.isBare, let branch = entry.branch, !branch.isEmpty else { continue }
            guard holders[branch] == nil else { continue }
            holders[branch] = standardised(entry.path) == project
                ? .projectCheckout(path: entry.path)
                : .otherWorktree(path: entry.path)
        }
        for (branch, name) in workspaceNames where !branch.isEmpty {
            holders[branch] = .workspace(name)
        }
        return holders
    }

    static func names(of workspaces: [Workspace], in repoID: RepoID) -> [String: String] {
        Dictionary(
            workspaces
                .filter { $0.state == .active && $0.repoID == repoID }
                .map { ($0.branch, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func standardised(_ path: String) -> String {
        let standard = URL(fileURLWithPath: path).standardizedFileURL.path
        return standard.count > 1 && standard.hasSuffix("/") ? String(standard.dropLast()) : standard
    }
}

public struct BranchInUse: Error, Sendable, Equatable, CustomStringConvertible {
    public let branch: String
    public let holder: BranchHolder

    public init(branch: String, holder: BranchHolder) {
        self.branch = branch
        self.holder = holder
    }

    public var description: String { holder.refusal(branch: branch) }
}
