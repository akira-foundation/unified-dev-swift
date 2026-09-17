import Foundation

public enum SubagentKind: Sendable, Hashable, CaseIterable {
    case agent
    case command

    static let commandTaskType = "local_bash"

    public init(taskType: String) {
        self = taskType == Self.commandTaskType ? .command : .agent
    }

    public var noun: String {
        switch self {
        case .agent: "subagent"
        case .command: "background command"
        }
    }

    public var writesTranscript: Bool { self == .agent }
}
