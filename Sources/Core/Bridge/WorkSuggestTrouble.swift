import Foundation

public enum WorkSuggestTrouble: Error, Sendable, Equatable {
    case noChat(tool: String)
    case missing(field: String)
    case tooLong(field: String, limit: Int)
    case hiddenCharacters(field: String)
    case controlInProject
    case needsProject
    case unknownProject(given: String, known: [String])
    case ambiguousProject(given: String, paths: [String])
    case full(undecided: Int)
    case callerHasGone
    case noSuggestionID
    case unknownSuggestion(String)
    case notYours
    case alreadyDecided(WorkSuggestion.State)
    case unexplained(tool: String, String)

    public var sentence: String {
        switch self {
        case .noChat(let tool):
            return """
                \(tool) puts a card in the chat that calls it, and this connection is not a chat \
                Unified Dev draws: it is the owner's own client, outside the app. Ask in Ask Unified \
                Dev instead, or start the work with workspace_start.
                """
        case .missing(let field):
            return "work_suggest needs '\(field)', and it cannot be blank. " + Self.hint(field)
        case let .tooLong(field, limit):
            return "'\(field)' is longer than the \(limit) characters Unified Dev puts on a card. Say it in fewer."
        case .hiddenCharacters(let field):
            return """
                '\(field)' holds invisible characters, Unicode tag characters or direction controls, \
                which would hide part of it from the owner on the card. Write it in plain text.
                """
        case .controlInProject:
            return """
                'project' has a line break or another control character in it, and no project name, \
                path or owner/repository does. Give it on one line.
                """
        case .needsProject:
            return """
                work_suggest needs a 'project' here, because this chat is in no workspace and nothing \
                else says where the work would go. Name a project Unified Dev has, give the absolute \
                path of a repository on this Mac, or give owner/repository for one on GitHub.
                """
        case let .unknownProject(given, known):
            let listing = known.isEmpty ? "no projects yet" : BridgeProjectLookup.listing(known)
            return """
                Unified Dev has no project called '\(given)'. It knows \(listing). Name one of those, \
                give the absolute path of the repository on this Mac, or give owner/repository for \
                one that is only on GitHub.
                """
        case let .ambiguousProject(given, paths):
            return "Unified Dev has \(paths.count) projects called '\(given)'. Name one by its path instead: "
                + BridgeProjectLookup.listing(paths) + "."
        case .full(let undecided):
            return """
                This workspace already has \(undecided) suggestions waiting for the owner, which is as \
                many as Unified Dev holds at once. Withdraw one you no longer stand behind with \
                work_withdraw, or leave it to the owner to decide. Retrying now is refused the same way.
                """
        case .callerHasGone:
            return "This workspace is no longer in Unified Dev's database, so there is nowhere to put a card."
        case .noSuggestionID:
            return "work_withdraw needs 'suggestion_id': the id work_suggest answered with."
        case .unknownSuggestion(let id):
            return "Unified Dev has no suggestion with the id '\(id)'. Use the id work_suggest answered with."
        case .notYours:
            return "That suggestion was made by another chat, and only the chat that made a suggestion may withdraw it."
        case .alreadyDecided(let state):
            return Self.decided(state)
        case let .unexplained(tool, message):
            return "Unified Dev could not complete \(tool): \(message)"
        }
    }

    private static func hint(_ field: String) -> String {
        switch field {
        case "title": "It names the work on the card, in a few words."
        case "why": "It is one sentence saying why you are suggesting this now."
        default: "It is everything the agent that does the work gets, because it cannot see this conversation."
        }
    }

    private static func decided(_ state: WorkSuggestion.State) -> String {
        switch state {
        case .pending:
            "That suggestion is waiting for the owner again, after a start that did not go through. "
                + "Call work_withdraw once more to take it back."
        case .withdrawn:
            "That suggestion is not waiting for the owner any more."
        case .starting:
            "The owner is starting that suggestion right now, so it cannot be withdrawn. If it is wrong, say so in this chat."
        case .startedWorkspace(_, let name), .startedHere(_, let name):
            "The owner has already started that suggestion as \"\(name)\", so it cannot be withdrawn. "
                + "If it is wrong, say so in this chat, where the owner will see it."
        case .dismissed:
            "The owner has already dismissed that suggestion. There is nothing to withdraw."
        }
    }
}
