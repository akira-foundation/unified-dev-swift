import Foundation

public struct SubagentRow: Sendable, Hashable, Identifiable {
    public enum Mark: Sendable, Hashable {
        case working
        case done
        case failed
        case stopped

        public var word: String {
            switch self {
            case .working: "Working"
            case .done: "Finished"
            case .failed: "Failed"
            case .stopped: "Stopped"
            }
        }
    }

    public enum Detail: Sendable, Hashable {
        case elapsed(seconds: Int)
        case retrying(AgentRetry)
        case summary(String)
        case none

        public var text: String {
            switch self {
            case .elapsed(let seconds): SubagentRow.duration(seconds)
            case .retrying(let retry): retry.readout
            case .summary(let summary): summary
            case .none: ""
            }
        }
    }

    public let id: SubagentID
    public let title: String
    public let mark: Mark
    public let detail: Detail
    public let opensOutput: Bool
    public let spokenValue: String

    static let detailLimit = 28

    public static func rows(_ roster: SubagentRoster, now: Date = Date()) -> [SubagentRow] {
        roster.subagents.map { SubagentRow($0, now: now) }
    }

    public init(_ subagent: Subagent, now: Date = Date()) {
        id = subagent.id
        title = Self.title(of: subagent)
        mark = switch subagent.state {
        case .running: .working
        case .completed: .done
        case .failed: .failed
        case .stopped: .stopped
        }
        detail = Self.detail(of: subagent, now: now)
        opensOutput = subagent.kind == .agent || subagent.hasOutput
        spokenValue = Self.spoken(subagent, detail: detail)
    }

    public static func title(of subagent: Subagent) -> String {
        let description = subagent.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { return description }
        let type = subagent.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "Subagent" : type
    }

    static func detail(of subagent: Subagent, now: Date = Date()) -> Detail {
        switch subagent.state {
        case .running:
            if let retry = subagent.retry { return .retrying(retry) }
            return .elapsed(seconds: subagent.secondsElapsed(at: now))
        case .completed, .failed, .stopped:
            let summary = shorten(subagent.summary)
            return summary.isEmpty ? .none : .summary(summary)
        }
    }

    static func shorten(_ text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard line.count > detailLimit else { return line }
        let cut = line.index(line.startIndex, offsetBy: detailLimit)
        let head = line[line.startIndex..<cut]
        if let space = head.lastIndex(of: " "), head.distance(from: space, to: head.endIndex) < 10 {
            return head[head.startIndex..<space].trimmingCharacters(in: .whitespaces) + "..."
        }
        return head.trimmingCharacters(in: .whitespaces) + "..."
    }

    public static func duration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "" }
        guard seconds >= 60 else { return "\(seconds)s" }
        let minutes = seconds / 60
        guard minutes < 60 else { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m \(seconds % 60)s"
    }

    static func spoken(_ subagent: Subagent, detail: Detail) -> String {
        let state = switch subagent.state {
        case .running: subagent.retry == nil ? "working" : "working, being retried"
        case .completed: "finished"
        case .failed: "failed"
        case .stopped: "stopped"
        }
        let text = detail.text
        return text.isEmpty ? state : "\(state), \(text)"
    }
}
