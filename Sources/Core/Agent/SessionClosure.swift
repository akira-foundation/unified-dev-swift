import Foundation

public struct SessionClosure: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let stopsATurn = SessionClosure(rawValue: 1 << 0)

    public static let leavesNoConversation = SessionClosure(rawValue: 1 << 1)

    public static func closing(isRunning: Bool, otherConversations: Int) -> SessionClosure {
        var cost: SessionClosure = []
        if isRunning { cost.insert(.stopsATurn) }
        if otherConversations <= 0 { cost.insert(.leavesNoConversation) }
        return cost
    }

    public var needsConfirmation: Bool { !isEmpty }

    public func title(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = trimmed.isEmpty ? "This conversation" : trimmed

        if contains(.stopsATurn) { return "\(subject) is still working" }
        if contains(.leavesNoConversation) { return "\(subject) is the only conversation here" }
        return "Close \(subject)?"
    }

    public var reasons: [String] {
        var lines: [String] = []
        if contains(.stopsATurn) {
            lines.append(
                """
                Closing it stops the agent. The turn it is in the middle of will not be finished, \
                and it cannot be resumed.
                """
            )
        }
        if contains(.leavesNoConversation) {
            lines.append(
                """
                It is the only conversation in this workspace, and a closed conversation does not \
                come back. The worktree and anything else open here are untouched, and a new \
                conversation can be started from the plus above the pane.
                """
            )
        }
        return lines
    }

    public var confirmTitle: String {
        contains(.stopsATurn) ? "Close anyway" : "Close it"
    }

    public var cancelTitle: String {
        contains(.stopsATurn) ? "Keep working" : "Keep it"
    }
}
