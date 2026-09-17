import Foundation

public struct SearchPanelField: Equatable, Sendable {
    public private(set) var mode: SearchPanelMode = .things
    public private(set) var text: String = ""
    private var stashed = ""

    public init() {}

    public static let commandPrefix: Character = ">"

    public mutating func type(_ typed: String) {
        guard mode == .things, let first = typed.first, first == Self.commandPrefix else {
            text = typed
            return
        }
        stashed = ""
        mode = .commands
        var rest = String(typed.dropFirst())
        if rest.first == " " { rest.removeFirst() }
        text = rest
    }

    public mutating func enterActions(on workspaceID: WorkspaceID) -> Bool {
        guard mode == .things else { return false }
        stashed = text
        mode = .actions(workspaceID)
        text = ""
        return true
    }

    public mutating func leaveMode() -> Bool {
        guard mode != .things else { return false }
        mode = .things
        text = stashed
        stashed = ""
        return true
    }

    public mutating func clear() {
        text = ""
    }

    public var isEmpty: Bool { text.isEmpty }

    public var query: String { text }
}
