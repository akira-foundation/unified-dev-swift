import Foundation

public struct ClearedBackgroundTasks: Sendable, Hashable {
    private var ids: Set<SubagentID> = []

    public init() {}

    public func hides(_ subagent: Subagent) -> Bool {
        subagent.state.isFinished && ids.contains(subagent.id)
    }

    public func hasVisibleTasks(in roster: SubagentRoster) -> Bool {
        (roster.subagents + roster.history).contains { !hides($0) }
    }

    public mutating func clear(_ roster: SubagentRoster) {
        ids.formUnion((roster.subagents + roster.history).filter(\.state.isFinished).map(\.id))
    }

    public mutating func forgetRunning(in roster: SubagentRoster) {
        ids.subtract(roster.subagents.filter { $0.state == .running }.map(\.id))
    }
}
