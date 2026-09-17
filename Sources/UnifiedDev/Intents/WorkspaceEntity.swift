import AppIntents
import Core

struct WorkspaceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Unified Dev Workspace",
        numericFormat: "\(placeholder: .int) workspaces"
    )

    static let defaultQuery = WorkspaceEntityQuery()

    var id: WorkspaceID

    @Property(title: "Name") var name: String
    @Property(title: "Project") var project: String
    @Property(title: "Branch") var branch: String
    @Property(title: "Folder") var folder: String
    @Property(title: "Status") var status: WorkspaceStatusAppEnum
    @Property(title: "Agent Running") var isAgentRunning: Bool
    @Property(title: "Lines Added") var additions: Int
    @Property(title: "Lines Removed") var deletions: Int
    @Property(title: "Changed Files") var changedFiles: Int
    @Property(title: "Pull Request") var pullRequest: String
    @Property(title: "Pull Request URL") var pullRequestURL: String

    init(
        workspace: Workspace,
        project: String,
        isAgentRunning: Bool,
        isAwaitingPermission: Bool = false,
        pullRequest: PullRequest?
    ) {
        self.id = workspace.id
        self.name = workspace.name
        self.project = project
        self.branch = workspace.branch
        self.folder = workspace.path
        self.status = WorkspaceStatusAppEnum(
            WorkspaceStatus.resolve(
                workspace: workspace,
                isRunning: isAgentRunning,
                pullRequest: pullRequest,
                isAwaitingPermission: isAwaitingPermission
            )
        )
        self.isAgentRunning = isAgentRunning
        self.additions = workspace.additions
        self.deletions = workspace.deletions
        self.changedFiles = workspace.changedFiles
        self.pullRequest = pullRequest.map { "#\($0.number) \($0.title)" } ?? ""
        self.pullRequestURL = pullRequest?.url ?? ""
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(project), \(statusLabel)"
        )
    }

    private var statusLabel: String {
        WorkspaceStatusAppEnum.caseDisplayRepresentations[status]
            .map { String(localized: $0.title) } ?? status.rawValue
    }
}
