import Foundation

public struct CarryOnFacts: Sendable, Equatable {
    public var branch: String
    public var baseBranch: String
    public var defaultBranch: String
    public var branches: [String]
    public var remoteBranches: [String]
    public var restoreSource: RestoreSource?
    public var agentSessionID: String?
    public var agentKind: AgentKind

    public init(
        branch: String,
        baseBranch: String,
        defaultBranch: String,
        branches: [String] = [],
        remoteBranches: [String] = [],
        restoreSource: RestoreSource? = nil,
        agentSessionID: String? = nil,
        agentKind: AgentKind = .claudeCode
    ) {
        self.branch = branch
        self.baseBranch = baseBranch
        self.defaultBranch = defaultBranch
        self.branches = branches
        self.remoteBranches = remoteBranches
        self.restoreSource = restoreSource
        self.agentSessionID = agentSessionID
        self.agentKind = agentKind
    }
}

public enum CarryOnRefusal: Sendable, Hashable {
    case stillLooking
    case projectGone
    case canBeRestored
    case neverRan
    case backendCannotResume(AgentKind)
    case noValidName
}

public enum CarryOnDecision: Sendable, Hashable {
    case carry(CarryOnPlan)
    case refuse(CarryOnRefusal)

    public var plan: CarryOnPlan? {
        if case .carry(let plan) = self { return plan }
        return nil
    }

    public var refusal: CarryOnRefusal? {
        if case .refuse(let refusal) = self { return refusal }
        return nil
    }

    public var isOffered: Bool { plan != nil }
}

public struct CarryOnPlan: Sendable, Hashable {
    public var branch: String
    public var baseBranch: String
    public var agentSessionID: String
    public var agentKind: AgentKind

    public init(branch: String, baseBranch: String, agentSessionID: String, agentKind: AgentKind) {
        self.branch = branch
        self.baseBranch = baseBranch
        self.agentSessionID = agentSessionID
        self.agentKind = agentKind
    }
}

public enum CarryOnGate {
    public static func decide(_ facts: CarryOnFacts) -> CarryOnDecision {
        guard let source = facts.restoreSource else { return .refuse(.stillLooking) }
        guard !source.canRebuild else { return .refuse(.canBeRestored) }

        guard let thread = facts.agentSessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !thread.isEmpty
        else { return .refuse(.neverRan) }

        guard facts.agentKind.canRunWorkspaces else {
            return .refuse(.backendCannotResume(facts.agentKind))
        }

        let taken = Set(facts.branches).union([facts.branch])
        let branch = ContinuationBranch.next(after: facts.branch, taken: taken)
        guard Git.isValidBranchName(branch), !taken.contains(branch) else {
            return .refuse(.noValidName)
        }

        return .carry(CarryOnPlan(
            branch: branch,
            baseBranch: WorkspaceStartContext.resolvedBaseBranch(
                current: facts.baseBranch,
                local: facts.branches,
                remote: facts.remoteBranches,
                defaultBranch: facts.defaultBranch
            ),
            agentSessionID: thread,
            agentKind: facts.agentKind
        ))
    }
}

public struct ArchivedCarryOn: Sendable, Hashable {
    public var name: String
    public var project: String
    public var previousBranch: String
    public var previousPath: String
    public var branch: String
    public var baseBranch: String

    public init(
        name: String,
        project: String,
        previousBranch: String,
        previousPath: String,
        branch: String,
        baseBranch: String
    ) {
        self.name = name
        self.project = project
        self.previousBranch = previousBranch
        self.previousPath = previousPath
        self.branch = branch
        self.baseBranch = baseBranch
    }

    public init(workspace: Workspace, project: String, plan: CarryOnPlan) {
        self.init(
            name: workspace.name,
            project: project,
            previousBranch: workspace.branch,
            previousPath: workspace.path,
            branch: plan.branch,
            baseBranch: plan.baseBranch
        )
    }

    public func promptValues() -> [String: String] {
        [
            PromptRegistry.CarryOnArchived.workspace: name,
            PromptRegistry.CarryOnArchived.project: project,
            PromptRegistry.CarryOnArchived.previousBranch: previousBranch,
            PromptRegistry.CarryOnArchived.previousPath: previousPath,
            PromptRegistry.CarryOnArchived.branch: branch,
            PromptRegistry.CarryOnArchived.baseBranch: baseBranch,
        ]
    }

    public func render(template: String) -> PromptRender {
        PromptTemplate.render(template, values: promptValues())
    }

    public static func standing(project: String, baseBranch: String) -> String {
        "The conversation can still be carried on: Unified Dev cuts a new worktree from \(baseBranch) "
            + "in \(project) and hands this chat to an agent there, with its own memory of it "
            + "intact. This archive is left exactly as it is."
    }
}

public extension WorkspaceManager {
    func carryOnFacts(
        workspace: Workspace,
        repo: Repo,
        session: Session?,
        source: RestoreSource?
    ) async -> CarryOnFacts {
        async let local = Git.branches(of: repo.path)
        async let references = Git.remoteBranches(of: repo.path)
        async let names = Git.remoteNames(of: repo.path)
        return CarryOnFacts(
            branch: workspace.branch,
            baseBranch: workspace.baseBranch,
            defaultBranch: repo.defaultBranch,
            branches: (try? await local) ?? [],
            remoteBranches: WorkspaceStartContext.primaryRemoteBranches(
                references: (try? await references) ?? [], remoteNames: (try? await names) ?? []
            ),
            restoreSource: source,
            agentSessionID: session?.agentSessionID,
            agentKind: session?.agentKind ?? .claudeCode
        )
    }
}
