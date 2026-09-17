import Foundation

public struct WorkspaceTabCensus: Sendable, Equatable {
    public var tabs: [WorkspaceTabReport]

    public init(tabs: [WorkspaceTabReport]) {
        self.tabs = tabs
    }

    public var json: JSONValue {
        .object([
            "tabs": .array(tabs.map(\.json)),
            "count": .integer(tabs.count),
            "note": .string(note),
        ])
    }

    public var note: String {
        var sentences: [String] = []

        if tabs.isEmpty {
            sentences.append(
                "That workspace has nothing open in the centre column at the moment, which "
                    + "usually means Unified Dev has not finished reading its chats yet."
            )
        } else {
            sentences.append(
                "'tab' is a place in the strip counting from 1, not an identity: it changes when "
                    + "a tab is opened, closed or dragged. Call workspace_tabs again before "
                    + "acting on a number you have been holding."
            )
        }

        let hasBrowser = tabs.contains { tab in
            tab.kind == .browser || tab.panes.contains { $0.kind == .browser }
        }
        if hasBrowser { sentences.append(PaneCensus.browserNote) }

        return sentences.joined(separator: " ")
    }
}

public struct WorkspaceTabReport: Sendable, Equatable {
    public var number: Int
    public var title: String
    public var isActive: Bool
    public var detail: WorkspaceTabDetail
    public var panes: [WorkspaceTabPane]

    public init(
        number: Int,
        title: String,
        isActive: Bool,
        detail: WorkspaceTabDetail,
        panes: [WorkspaceTabPane] = []
    ) {
        self.number = number
        self.title = title
        self.isActive = isActive
        self.detail = detail
        self.panes = panes
    }

    public var kind: PaneCensusKind { detail.kind }

    public var json: JSONValue {
        var fields: [String: JSONValue] = [
            "tab": .integer(number),
            "kind": .string(kind.rawValue),
            "title": .string(title),
            "active": .bool(isActive),
        ]
        fields[kind.rawValue] = detail.json
        if !panes.isEmpty {
            fields["split_into"] = .array(panes.map(\.json))
        }
        return .object(fields)
    }
}

public enum WorkspaceTabDetail: Sendable, Equatable {
    case chat(WorkspaceTabChat)
    case terminal(WorkspaceTabTerminal)
    case browser(BrowserPaneReport)
    case review(WorkspaceTabReview)
    case notes(WorkspaceTabNote)

    public var kind: PaneCensusKind {
        switch self {
        case .chat: .chat
        case .terminal: .terminal
        case .browser: .browser
        case .review: .review
        case .notes: .notes
        }
    }

    public var json: JSONValue {
        switch self {
        case .chat(let chat): chat.json
        case .terminal(let terminal): terminal.json
        case .browser(let browser): browser.json
        case .review(let review): review.json
        case .notes(let note): note.json
        }
    }
}

public struct WorkspaceTabChat: Sendable, Equatable {
    public var agent: AgentKind
    public var state: SessionState
    public var messages: Int

    public init(agent: AgentKind, state: SessionState, messages: Int) {
        self.agent = agent
        self.state = state
        self.messages = messages
    }

    public var json: JSONValue {
        .object([
            "agent": .string(agent.rawValue),
            "state": .string(state.rawValue),
            "running": .bool(state == .running),
            "messages": .integer(messages),
        ])
    }
}

public struct WorkspaceTabTerminal: Sendable, Equatable {
    public var directory: String
    public var isLive: Bool

    public init(directory: String, isLive: Bool) {
        self.directory = directory
        self.isLive = isLive
    }

    public var json: JSONValue {
        .object([
            "directory": .string(directory),
            "live": .bool(isLive),
            "note": .string(
                isLive
                    ? "Unified Dev knows where this shell was started, not what is running in it now."
                    : "Nobody has opened this tab in this run of Unified Dev, so no shell has been "
                        + "started for it yet."
            ),
        ])
    }
}

public struct WorkspaceTabReview: Sendable, Equatable {
    public var file: String

    public init(file: String) {
        self.file = file
    }

    public var json: JSONValue {
        var fields: [String: JSONValue] = [:]
        if file.isEmpty {
            fields["showing"] = .string("all changes")
        } else {
            fields["file"] = .string(file)
        }
        fields["note"] = .string(
            "The diff itself is not here. The worktree is an ordinary git checkout, so read it "
                + "with your own tools."
        )
        return .object(fields)
    }
}

public struct WorkspaceTabNote: Sendable, Equatable {
    public var characters: Int

    public init(characters: Int) {
        self.characters = characters
    }

    public var json: JSONValue {
        .object([
            "characters": .integer(characters),
            "note": .string(
                characters == 0
                    ? "The note is empty."
                    : "The text of the note is the person's own and is not reported here."
            ),
        ])
    }
}

public struct WorkspaceTabPane: Sendable, Equatable {
    public var kind: PaneCensusKind
    public var title: String
    public var browser: Int?

    public init(kind: PaneCensusKind, title: String, browser: Int? = nil) {
        self.kind = kind
        self.title = title
        self.browser = browser
    }

    public var json: JSONValue {
        var fields: [String: JSONValue] = [
            "kind": .string(kind.rawValue),
            "title": .string(title),
        ]
        if let browser { fields["browser"] = .integer(browser) }
        return .object(fields)
    }
}
