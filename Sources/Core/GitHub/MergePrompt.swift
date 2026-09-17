import Foundation

public struct MergePromptContext: Sendable, Hashable {
    public static let noBranch = "(gh did not report the branch name: do not guess it, and leave "
        + "the branch on the server alone)"

    public static let noTitle = "(gh did not report the title)"

    public var workspaceName: String
    public var number: Int
    public var title: String
    public var branch: String
    public var baseBranch: String
    public var method: GitHub.MergeMethod

    public init(
        workspaceName: String,
        number: Int,
        title: String,
        branch: String,
        baseBranch: String,
        method: GitHub.MergeMethod
    ) {
        self.workspaceName = workspaceName
        self.number = number
        self.title = title
        self.branch = branch
        self.baseBranch = baseBranch
        self.method = method
    }

    public var values: [String: String] {
        [
            PromptRegistry.MergePullRequest.workspace: workspaceName,
            PromptRegistry.MergePullRequest.number: String(number),
            PromptRegistry.MergePullRequest.title: title.isEmpty ? Self.noTitle : title,
            PromptRegistry.MergePullRequest.branch: branch.isEmpty ? Self.noBranch : branch,
            PromptRegistry.MergePullRequest.baseBranch: baseBranch,
            PromptRegistry.MergePullRequest.method: method.phrase,
            PromptRegistry.MergePullRequest.methodFlag: method.flag,
        ]
    }

    public func render(template: String) -> PromptRender {
        PromptTemplate.render(template, values: values)
    }
}

public extension GitHub.MergeMethod {
    var phrase: String {
        switch self {
        case .merge: "merge commit"
        case .squash: "squash merge"
        case .rebase: "rebase merge"
        }
    }

    var flag: String { "--\(rawValue)" }
}
