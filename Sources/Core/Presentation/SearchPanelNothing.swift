import Foundation

public enum SearchPanelNothing: Equatable, Sendable {
    case nothingYet
    case noMatch(String)
    case noLiveMatch(String, archived: Int)
    case noHiddenMatch(String, hidden: Int)
    case noCommand(String)

    public var title: String {
        switch self {
        case .nothingYet: "Nothing to show yet"
        case .noMatch, .noLiveMatch, .noHiddenMatch: "No results"
        case .noCommand: "No such command"
        }
    }

    public var message: String {
        switch self {
        case .nothingYet:
            "Add a project and start a workspace, and what you are working on turns up here."
        case .noMatch(let query):
            "Nothing in Unified Dev matches \(quoted(query))."
        case .noHiddenMatch(let query, let hidden):
            hidden == 1
                ? "Nothing in your visible work matches \(quoted(query)). 1\u{00A0}hidden project is left out."
                : "Nothing in your visible work matches \(quoted(query)). \(hidden)\u{00A0}hidden projects are left out."
        case .noLiveMatch(let query, let archived):
            archived == 1
                ? "Nothing in your live work matches \(quoted(query)). 1\u{00A0}archived workspace does."
                : "Nothing in your live work matches \(quoted(query)). \(archived)\u{00A0}archived workspaces do."
        case .noCommand(let query):
            "No menu item matches \(quoted(query))."
        }
    }

    public func indexNotice(isIndexing: Bool) -> String? {
        guard isIndexing else { return nil }
        switch self {
        case .noMatch, .noLiveMatch, .noHiddenMatch: break
        case .nothingYet, .noCommand: return nil
        }
        return "The transcript index is still building, so older conversations are not searchable yet."
    }

    private func quoted(_ query: String) -> String {
        "\u{201C}\(query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}"
    }
}
