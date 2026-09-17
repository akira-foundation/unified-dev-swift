import Foundation

public struct PullRequestPromptContext: Sendable, Hashable {
    public static let noTask = "(nothing recorded: this workspace has no opening prompt)"
    public static let noChanges = "(git reports no changes against the target branch)"

    public static let fileLimit = 40

    public var workspaceName: String
    public var branch: String
    public var baseBranch: String
    public var task: String
    public var changes: String

    public init(
        workspaceName: String,
        branch: String,
        baseBranch: String,
        task: String,
        changes: String
    ) {
        self.workspaceName = workspaceName
        self.branch = branch
        self.baseBranch = baseBranch
        self.task = task
        self.changes = changes
    }

    public var values: [String: String] {
        [
            PromptRegistry.CreatePullRequest.workspace: workspaceName,
            PromptRegistry.CreatePullRequest.branch: branch,
            PromptRegistry.CreatePullRequest.baseBranch: baseBranch,
            PromptRegistry.CreatePullRequest.task: task.isEmpty ? Self.noTask : task,
            PromptRegistry.CreatePullRequest.changes: changes.isEmpty ? Self.noChanges : changes,
        ]
    }

    public func render(template: String) -> PromptRender {
        PromptTemplate.render(template, values: values)
    }

    public static func changeSummary(_ files: [ChangedFile], limit: Int = fileLimit) -> String {
        guard !files.isEmpty else { return "" }

        var lines = files.prefix(limit).map { file -> String in
            let name = file.oldPath.map { "\($0) -> \(file.path)" } ?? file.path
            let detail = file.isBinary ? "binary" : "+\(file.additions)/-\(file.deletions)"
            return "- \(name) (\(label(for: file.change)), \(detail))"
        }

        let remaining = files.count - lines.count
        if remaining > 0 {
            lines.append("- ...and \(remaining) more file\(remaining == 1 ? "" : "s")")
        }
        return lines.joined(separator: "\n")
    }

    static func label(for change: ChangedFile.Change) -> String {
        switch change {
        case .added: "added"
        case .modified: "modified"
        case .deleted: "deleted"
        case .renamed: "renamed"
        case .copied: "copied"
        case .untracked: "untracked"
        }
    }
}

public enum UserTurnPayload {
    public static func text(from payload: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        let text = content
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
        return text.isEmpty ? nil : text
    }
}
