import Foundation

public enum HomeEmptyState: Sendable, Equatable {
    case noProjects
    case noWorkspaces
    case noMatch(query: String, scope: HomeScope)
    case noneInChosenProjects(phrase: String)
    case emptyScope(HomeScope)

    public static func resolve(
        hasProjects: Bool,
        hasAnyWorkspace: Bool,
        isListEmpty: Bool,
        query: String,
        scope: HomeScope,
        hasProjectFilter: Bool,
        projectPhrase: String
    ) -> HomeEmptyState? {
        guard hasProjects else { return .noProjects }
        guard hasAnyWorkspace else { return .noWorkspaces }
        guard isListEmpty else { return nil }

        let needle = query.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty { return .noMatch(query: needle, scope: scope) }
        if hasProjectFilter { return .noneInChosenProjects(phrase: projectPhrase) }
        return .emptyScope(scope)
    }

    public var title: String {
        switch self {
        case .noProjects: "No projects yet"
        case .noWorkspaces: "No workspaces yet"
        case let .noMatch(_, scope):
            switch scope {
            case .transcripts: "Nothing was said about it"
            case .archived: "Nothing archived matches"
            default: "No results"
            }
        case let .noneInChosenProjects(phrase): "Nothing in \(phrase)"
        case let .emptyScope(scope):
            switch scope {
            case .needsYou: "Nothing is waiting for you"
            case .running: "No agent is running"
            case .live: "Nothing is live"
            case .archived: "Nothing has been archived"
            default: "Nothing to show"
            }
        }
    }

    public var symbol: String {
        switch self {
        case .noProjects: "folder.badge.plus"
        case .noWorkspaces: "square.stack.3d.up"
        case .noMatch: "magnifyingglass"
        case .noneInChosenProjects: "folder"
        case let .emptyScope(scope):
            switch scope {
            case .needsYou: "bell"
            case .running: "play.circle"
            case .archived: "archivebox"
            default: "square.stack.3d.up"
            }
        }
    }

    public var message: String {
        switch self {
        case .noProjects:
            return "Start a new project, or point Unified Dev at a repository you already have."
        case .noWorkspaces:
            return "A workspace gets a branch, a worktree and an agent of its own."
        case let .noMatch(query, scope):
            let quoted = "\u{201C}\(query)\u{201D}"
            switch scope {
            case .transcripts:
                return "No agent on this Mac has said \(quoted)."
            case .archived:
                return "No archived workspace and no archived transcript matches \(quoted)."
            case .workspaces:
                return "Nothing here is called, branched or filed under \(quoted)."
            default:
                return "Nothing is called, branched or filed under \(quoted), and no agent said it."
            }
        case .noneInChosenProjects:
            return "The other projects still have work in them."
        case let .emptyScope(scope):
            switch scope {
            case .needsYou:
                return "No agent has asked a question, and every finished turn has been read."
            case .running:
                return "Nothing on this Mac is mid turn."
            case .live:
                return "Every workspace here has been archived."
            case .archived:
                return "Archiving a workspace removes its worktree and keeps everything it said."
            default:
                return "Nothing on this Mac matches what the strip is asking for."
            }
        }
    }

    public var actionTitle: String {
        switch self {
        case .noProjects: "Start a project"
        case .noWorkspaces: "New workspace"
        case .noMatch: "Clear the search"
        case .noneInChosenProjects: "Show all projects"
        case .emptyScope: "Show everything"
        }
    }
}
