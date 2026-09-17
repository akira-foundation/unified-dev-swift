import Foundation

public enum AgentExitCause: Sendable, Hashable {
    case crashed(String)
    case missing
    case reported(String)
    case silent
    case endedMidTurn
    case storage(String)
    case notStarted(String)
}

public struct AgentExit: Sendable, Hashable {
    public let status: Int?
    public let cause: AgentExitCause
    public let detail: String
    public let command: String

    public init(status: Int?, cause: AgentExitCause, detail: String, command: String = "") {
        self.status = status
        self.cause = cause
        self.detail = detail
        self.command = command
    }

    public var title: String {
        if case .storage = cause { return "Not saved" }
        if case .notStarted = cause { return "Not sent" }
        if case .endedMidTurn = cause { return "Turn never finished" }
        return status.map { "Agent exited (\($0))" } ?? "Agent error"
    }

    public var summary: String {
        switch cause {
        case .crashed(let error):
            Self.oneLine(Self.stopped("The CLI crashed: \(error)"))
        case .missing:
            "Unified Dev could not find the agent's command."
        case .reported(let text):
            Self.oneLine(text)
        case .silent:
            "It stopped without printing anything."
        case .endedMidTurn:
            "The agent's process ended in the middle of this turn, without an error and without "
                + "finishing."
        case .storage(let message):
            Self.oneLine(message)
        case .notStarted(let message):
            Self.oneLine(message)
        }
    }

    public var advice: String {
        switch cause {
        case .crashed:
            """
            This is a fault in the CLI itself rather than in your work. Nothing in this \
            conversation was lost, and everything the agent had already changed is still in the \
            worktree. Run the CLI once in a terminal to see whether it starts at all, update it if \
            it does not, then send the turn again.
            """ + ranCommand
        case .missing:
            """
            Install the agent's CLI, or put it somewhere Unified Dev looks, then send the turn again. \
            Nothing in this conversation was lost.
            """
        case .reported:
            """
            Nothing in this conversation was lost, and everything the agent had already changed is \
            still in the worktree. Open this row for everything the CLI printed, then send the \
            turn again.
            """ + ranCommand
        case .silent:
            """
            Nothing in this conversation was lost, and everything the agent had already changed is \
            still in the worktree. Send the turn again, and if it stops here a second time, run \
            the CLI once in a terminal to see what it says.
            """ + ranCommand
        case .endedMidTurn:
            """
            Nothing in this conversation was lost, and everything the agent had already changed is \
            still in the worktree. Send the turn again. It is worth checking the limits panel \
            first: the CLI has been seen to end a turn this way with the weekly allowance nearly \
            spent.
            """ + ranCommand
        case .storage:
            """
            The agent itself kept running. It is Unified Dev's copy of the conversation that is missing \
            a row, so check that the disk is not full, then reopen the workspace.
            """
        case .notStarted:
            """
            Nothing was said to the agent and no files were touched. Your message is still in the \
            queue above the composer. Choose Try Again there when the agent is available, or edit \
            or delete the message. If trying again fails, quit and reopen Unified Dev to restart the \
            agent connection.
            """
        }
    }

    private var ranCommand: String {
        command.isEmpty ? "" : " Unified Dev ran \(command)."
    }

    public var hasDetail: Bool {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != summary
    }

    public static func decode(_ payload: Data) -> AgentExit {
        guard let json = JSONValue.parse(payload) else {
            return AgentExit(status: nil, cause: .silent, detail: "")
        }
        return read(json)
    }

    public static func read(_ json: JSONValue?) -> AgentExit {
        let status = json?["status"]?.intValue
        let stderr = json?["stderr"]?.stringValue ?? ""
        let command = json?["command"]?.stringValue ?? ""

        if json?["subtype"]?.stringValue == "storage" {
            let message = json?["message"]?.stringValue ?? ""
            let cause: AgentExitCause = message.isEmpty ? .silent : .storage(message)
            return AgentExit(status: status, cause: cause, detail: message)
        }

        if json?["subtype"]?.stringValue == "notStarted" {
            let message = json?["message"]?.stringValue ?? ""
            let cause: AgentExitCause = message.isEmpty ? .silent : .notStarted(message)
            return AgentExit(status: status, cause: cause, detail: message)
        }

        if json?["subtype"]?.stringValue == UnfinishedRun.abandonedSubtype {
            return AgentExit(status: status, cause: .endedMidTurn, detail: stderr, command: command)
        }

        return AgentExit(
            status: status,
            cause: cause(status: status, stderr: stderr),
            detail: stderr,
            command: command
        )
    }

    public static func cause(status: Int?, stderr: String) -> AgentExitCause {
        let text = stripEscapes(stderr)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .silent }

        if status == 127, text.contains(Self.notFoundMarker) { return .missing }

        if let error = errorLine(inStack: text) { return .crashed(error) }

        return .reported(readable(text))
    }

    static let notFoundMarker = "not found on PATH"

    static let lineLimit = 400

    static let summaryLimit = 200

    static var verbatimLimit: Int { summaryLimit }

    static func errorLine(inStack text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let firstFrame = lines.firstIndex(where: isStackFrame) else { return nil }

        for index in stride(from: firstFrame - 1, through: 0, by: -1) {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard line.count <= lineLimit else { return nil }
            guard let separator = line.range(of: ": "),
                  line.distance(from: line.startIndex, to: separator.lowerBound) <= 80,
                  separator.lowerBound != line.startIndex,
                  separator.upperBound != line.endIndex
            else { return nil }
            return cut(line)
        }
        return nil
    }

    static func isStackFrame(_ line: String) -> Bool {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        guard indent.count >= 2 else { return false }
        let rest = line.dropFirst(indent.count)
        return rest.hasPrefix("at ") && rest.count > 3
    }

    static func readable(_ text: String) -> String {
        let folded = oneLine(text, limit: verbatimLimit)
        if folded.count <= verbatimLimit { return folded }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.count > lineLimit { continue }
            return cut(trimmed)
        }
        return "The CLI printed \(text.count) characters of output and no message."
    }

    static func stripEscapes(_ text: String) -> String {
        guard text.contains("\u{1B}") else { return text }

        var out = ""
        out.reserveCapacity(text.count)
        var iterator = text.makeIterator()
        var pending: Character?

        while let character = pending ?? iterator.next() {
            pending = nil
            guard character == "\u{1B}" else {
                out.append(character)
                continue
            }
            guard let next = iterator.next() else { break }
            if next == "[" {
                while let inner = iterator.next() {
                    if inner.isLetter { break }
                }
            } else if next == "]" {
                while let inner = iterator.next() {
                    if inner == "\u{07}" { break }
                    if inner == "\u{1B}" { pending = inner; break }
                }
            }
        }
        return out
    }

    static func oneLine(_ text: String, limit: Int = summaryLimit) -> String {
        var out = ""
        out.reserveCapacity(min(text.count, limit + 1))
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                pendingSpace = !out.isEmpty
                continue
            }
            if pendingSpace {
                out.append(" ")
                pendingSpace = false
            }
            out.append(character)
            if out.count > limit {
                out.removeLast()
                return out + "\u{2026}"
            }
        }
        return out
    }

    static func stopped(_ text: String) -> String {
        guard let last = text.last, !".!?".contains(last) else { return text }
        return text + "."
    }

    static func cut(_ text: String) -> String {
        guard text.count > summaryLimit else { return text }
        return String(text.prefix(summaryLimit)) + "\u{2026}"
    }
}
