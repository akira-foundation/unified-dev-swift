import Foundation

public enum WorkSuggestionWording {
    public static let gone = "This suggestion is no longer in Unified Dev."

    public static let withdrawn = "Withdrawn by the agent"

    public static let hereElsewhere = """
        Here starts a subagent in the workspace the suggestion came from, so it only works for work \
        in that workspace's own project. Start it as a new workspace instead.
        """

    public static func taken(_ state: WorkSuggestion.State) -> String {
        switch state {
        case .pending: "It is waiting for you again."
        case .starting: "It is already starting."
        case .startedWorkspace(_, let name), .startedHere(_, let name): "It has already started, as \(name)."
        case .dismissed: "It was dismissed."
        case .withdrawn: withdrawn
        }
    }

    public static func cloneFirst(_ slug: String) -> String {
        "\(slug) is only on GitHub. Clone it and add it as a project, and then it can be started from here."
    }

    public static func notARepository(_ path: String) -> String {
        """
        \(path) is not a git repository, and Unified Dev does not make one from a suggestion. Add it \
        with Add Project, which offers to set it up, and start the work from there.
        """
    }

    public static func sentence(for refusal: LaunchRefusal) -> String {
        switch refusal {
        case .overAllowance(_, retry: .whenAWorkspaceIsArchived(let limit)):
            """
            The workspace that suggested this already has \(limit) workspaces it started still open, \
            which is as many as Unified Dev lets one workspace start. Try again once one of them is archived.
            """
        case .overAllowance(_, retry: .after(let date)):
            """
            Unified Dev has started as many workspaces from outside a workspace as it does in \
            \(Int(WorkspaceStartAllowance.ownerWindow / 60)) minutes. Try again after \
            \(date.formatted(date: .omitted, time: .shortened)).
            """
        case .unavailable(let sentence), .failed(let sentence):
            sentence
        }
    }

    public static func sentence(for refusal: CrewLaunchRefusal) -> String {
        switch refusal {
        case .rule(.tooMany(let running)):
            """
            \(running) subagents are already running in this workspace, which is as many as Unified \
            Dev runs at once. Try again when one of them stops.
            """
        case .rule(.notAnOrchestrator):
            "This chat is itself a subagent, and a subagent cannot start one. Start it as a new workspace instead."
        case .rule(.nameTaken(let name)):
            "This workspace already has a subagent called \"\(name)\"."
        case .rule(.noName):
            "The suggestion has no title to name a subagent after."
        case .noTask:
            "The suggestion has no prompt to give the agent."
        case .unavailable(let message):
            "Unified Dev could not read this workspace's subagents: \(message)"
        case .refused(let sentence):
            sentence
        }
    }
}
