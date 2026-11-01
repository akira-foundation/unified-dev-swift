import Foundation

public struct CodexBackgroundCommands: Sendable {
    public enum Change: Sendable, Hashable {
        case started(SubagentStart)
        case finished(id: SubagentID, status: String, summary: String, output: String)
    }

    private var inTurn: [String: CodexCommandExecution] = [:]
    private var outlived: Set<String> = []

    public init() {}

    public static func id(for itemID: String) -> SubagentID { SubagentID("codex-exec:\(itemID)") }

    public static func outputURL(for id: SubagentID, in directory: URL) -> URL {
        let name = id.rawValue.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }
        return directory.appending(path: String(name) + ".output")
    }

    public mutating func receive(_ event: CodexEvent, parentThreadID: String) -> [Change] {
        switch event {
        case .itemStarted(let item) where item.threadID == parentThreadID:
            guard case .commandExecution(let run) = item.item, run.status == .inProgress else { return [] }
            inTurn[run.id] = run
            return []

        case .itemCompleted(let item) where item.threadID == parentThreadID:
            guard case .commandExecution(let run) = item.item else { return [] }
            inTurn[run.id] = nil
            guard outlived.remove(run.id) != nil else { return [] }
            return [.finished(
                id: Self.id(for: run.id),
                status: Self.status(of: run),
                summary: run.exitCode.map { "exit \($0)" } ?? "",
                output: run.aggregatedOutput
            )]

        case .turnCompleted(let turn) where turn.threadID == parentThreadID:
            let running = inTurn.values.sorted { $0.id < $1.id }
            inTurn = [:]
            outlived.formUnion(running.map(\.id))
            return running.map { run in
                .started(SubagentStart(
                    id: Self.id(for: run.id),
                    description: ToolLiteral.unwrapShell(run.command),
                    isBackgrounded: true,
                    taskType: SubagentKind.commandTaskType
                ))
            }

        default:
            return []
        }
    }

    static func status(of run: CodexCommandExecution) -> String {
        switch run.status {
        case .completed: run.exitCode.map { $0 == 0 ? "completed" : "failed" } ?? "completed"
        case .failed: "failed"
        case .declined: "stopped"
        case .inProgress, .unknown: run.exitCode == 0 ? "completed" : "failed"
        }
    }
}
