import Foundation

public struct BackgroundTaskList: Sendable, Hashable {
    public struct Row: Sendable, Hashable, Identifiable {
        public let id: SubagentID
        public let kind: SubagentKind
        public let title: String
        public let mark: SubagentRow.Mark
        public let detail: String
        public let canStop: Bool

        public var openHelp: String {
            kind == .command ? "Show what this command printed" : SubagentRunLink.openHelp
        }

        init(_ subagent: Subagent, now: Date) {
            id = subagent.id
            kind = subagent.kind
            title = SubagentRow.title(of: subagent)
            mark = SubagentRow(subagent, now: now).mark
            canStop = subagent.state == .running
            let state = subagent.state == .running ? "Running" : mark.word
            let elapsed = SubagentRow.duration(subagent.secondsElapsed(at: now))
            detail = ([kind == .command ? "Command" : "Subagent", state] + (elapsed.isEmpty ? [] : [elapsed]))
                .joined(separator: " · ")
        }
    }

    public let rows: [Row]
    public let runningCount: Int

    public init(_ roster: SubagentRoster, now: Date = Date()) {
        let live = Set(roster.subagents.map(\.id))
        let running = roster.subagents
            .filter { $0.state == .running }
            .sorted { $0.startedAt < $1.startedAt }
        let finished = (roster.subagents.filter(\.state.isFinished)
            + roster.history.filter { !live.contains($0.id) })
            .sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
        rows = (running + finished).map { Row($0, now: now) }
        runningCount = running.count
    }

    public var isEmpty: Bool { rows.isEmpty }

    public var label: String? {
        guard !rows.isEmpty else { return nil }
        if runningCount > 0 { return "\(runningCount) running" }
        return rows.count == 1 ? "1 task" : "\(rows.count) tasks"
    }

    public var spokenLabel: String? {
        guard !rows.isEmpty else { return nil }
        let total = rows.count == 1 ? "1 background task" : "\(rows.count) background tasks"
        return runningCount > 0 ? "\(total), \(runningCount) running" : total
    }
}
