import Foundation

public enum RevealTarget: Sendable, Equatable {
    case workspace(WorkspaceID)
    case home(HomeFilter)
}

public struct RevealPlan: Sendable, Equatable {
    public let target: RevealTarget
    public let sentence: String

    public init(target: RevealTarget, sentence: String) {
        self.target = target
        self.sentence = sentence
    }
}

public enum RevealOutcome: Sendable, Equatable {
    case revealed(String)
    case refused(String)
}

public struct RevealOrder: Sendable, Equatable {
    public var workspace: String?
    public var project: String?
    public var scope: HomeScope
    public var search: String

    public init(
        workspace: String? = nil,
        project: String? = nil,
        scope: HomeScope = RevealChoice.scopeWhenUnnamed,
        search: String = ""
    ) {
        self.workspace = workspace
        self.project = project
        self.scope = scope
        self.search = search
    }
}

public enum RevealChoice {
    public static func parse(
        workspace: JSONValue?,
        project: JSONValue?,
        scope: JSONValue?,
        search: JSONValue?
    ) -> Result<RevealOrder, PaneRefusal> {
        let workspaceName = text(workspace)
        let projectName = text(project)
        let query = text(search) ?? ""

        var narrowing = Self.scopeWhenUnnamed
        if let raw = text(scope) {
            guard let known = HomeScope(rawValue: raw), Self.offered.contains(known) else {
                return .failure(PaneRefusal(
                    "'\(raw)' is not one of Home's scopes. They are: "
                        + Self.offered.map(\.rawValue).joined(separator: ", ") + "."
                ))
            }
            narrowing = known
        }

        if workspaceName != nil, projectName != nil || narrowing != .all || !query.isEmpty {
            return .failure(PaneRefusal(
                "reveal points at one workspace, or at Home narrowed by project, scope and "
                    + "search. Asking for both at once leaves it ambiguous which you meant, so "
                    + "pass 'workspace' on its own, or leave it out and pass the rest."
            ))
        }

        return .success(RevealOrder(
            workspace: workspaceName, project: projectName, scope: narrowing, search: query
        ))
    }

    static let offered: [HomeScope] = [.all, .needsYou, .running, .live, .archived]

    public static let scopeWhenUnnamed = HomeScope.all

    public static func resolve(
        _ order: RevealOrder,
        workspaces: [Workspace],
        projects: [Repo]
    ) -> Result<RevealPlan, PaneRefusal> {
        if let name = order.workspace {
            return workspaceTarget(name, among: workspaces, projects: projects)
        }

        var filter = HomeFilter(query: order.search, scope: order.scope)
        var project: Repo?
        if let name = order.project {
            switch match(name, among: projects) {
            case .failure(let refusal): return .failure(refusal)
            case .success(let found):
                project = found
                filter.projects = [found.id]
            }
        }

        return .success(RevealPlan(target: .home(filter), sentence: homeSentence(filter, project: project)))
    }

    private static func workspaceTarget(
        _ name: String,
        among workspaces: [Workspace],
        projects: [Repo]
    ) -> Result<RevealPlan, PaneRefusal> {
        switch BridgeWorkspaceLookup.find(name, among: workspaces) {
        case .found(let workspace):
            return .success(RevealPlan(
                target: .workspace(workspace.id),
                sentence: sentence(for: workspace, projects: projects)
            ))
        case .unknown:
            return .failure(PaneRefusal(
                "There is no workspace called '\(name)'. There is: "
                    + list(workspaces.map(\.name)) + "."
            ))
        case .ambiguous(let matches):
            return .failure(PaneRefusal(
                "\(matches.count) workspaces are called '\(name)', in "
                    + list(matches.map { projectName($0, projects: projects) })
                    + ". Pass the workspace's id instead, which workspace_list prints."
            ))
        }
    }

    private static func match(_ name: String, among projects: [Repo]) -> Result<Repo, PaneRefusal> {
        let needle = name.lowercased()
        if let exact = projects.first(where: { $0.name.lowercased() == needle }) { return .success(exact) }
        if let byPath = projects.first(where: { $0.path.lowercased() == needle }) { return .success(byPath) }
        return .failure(PaneRefusal(
            "There is no project called '\(name)'. There is: " + list(projects.map(\.name)) + "."
        ))
    }

    private static func sentence(for workspace: Workspace, projects: [Repo]) -> String {
        "Unified Dev is showing \(workspace.name) in \(projectName(workspace, projects: projects))."
    }

    private static func homeSentence(_ filter: HomeFilter, project: Repo?) -> String {
        var clauses = ["showing \(filter.scope.label(searching: false))"]
        if let project { clauses.append("in \(project.name)") }
        if !filter.query.isEmpty { clauses.append("matching '\(filter.query)'") }
        return "Unified Dev is on Home, " + clauses.joined(separator: ", ") + "."
    }

    private static func projectName(_ workspace: Workspace, projects: [Repo]) -> String {
        projects.first { $0.id == workspace.repoID }?.name ?? "a project Unified Dev no longer has"
    }

    static func list(_ names: [String]) -> String { BridgeWorkspaceLookup.list(names) }

    private static func text(_ value: JSONValue?) -> String? {
        guard let raw = value?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }
        return raw
    }
}
