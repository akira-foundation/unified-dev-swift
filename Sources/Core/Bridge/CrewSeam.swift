import Foundation

public struct CrewOrder: Sendable, Equatable {
    public var name: String
    public var task: String
    public var model: String?
    public var effort: String?

    public init(name: String, task: String, model: String? = nil, effort: String? = nil) {
        self.name = name
        self.task = task
        self.model = model
        self.effort = effort
    }
}

public enum CrewStartOutcome: Sendable, Equatable {
    case started(String)
    case refused(String)
}

public enum CrewSayOutcome: Sendable, Equatable {
    case delivered(String)
    case refused(String)
}

public enum CrewStopOutcome: Sendable, Equatable {
    case stopped(String)
    case refused(String)
}

public typealias CrewStarting =
    @Sendable (CrewOrder, SessionID, WorkspaceID) async -> CrewStartOutcome

public typealias CrewSaying =
    @Sendable (String?, String, SessionID, WorkspaceID) async -> CrewSayOutcome

public typealias CrewStopping =
    @Sendable (String, SessionID, WorkspaceID) async -> CrewStopOutcome
