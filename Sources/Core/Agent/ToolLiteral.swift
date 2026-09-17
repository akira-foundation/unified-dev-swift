import Foundation

public enum ToolLiteral {
    public static func of(name: String, input: JSONValue) -> String? {
        if name.hasPrefix("mcp__") { return namedFile(in: input) }

        switch name {
        case "Read":
            return text(input, "file_path") ?? text(input, "notebook_path")
        case "Write", "Edit", "MultiEdit":
            return text(input, "file_path")
        case "NotebookEdit":
            return text(input, "notebook_path")

        case "Bash":
            return text(input, "command")
        case "SlashCommand":
            return text(input, "command")

        case "BashOutput":
            return text(input, "bash_id") ?? text(input, "shell_id")
        case "KillShell", "KillBash":
            return text(input, "shell_id") ?? text(input, "bash_id")
        case "TaskOutput", "TaskStop":
            return text(input, "task_id") ?? text(input, "agent_id")

        case "Glob", "Grep":
            return text(input, "pattern")
        case "ToolSearch":
            return text(input, "query")

        case "WebFetch":
            return text(input, "url")

        default:
            return namedFile(in: input)
        }
    }

    public static func isCode(name: String, input: JSONValue) -> Bool {
        of(name: name, input: input) != nil
    }

    public static func of(codex item: CodexItem) -> String? {
        switch item {
        case .commandExecution(let run):
            let command = unwrapShell(run.command)
            return command.isEmpty ? nil : command
        case .fileChange(let change):
            guard change.changes.count == 1 else { return nil }
            let path = change.changes[0].path
            return path.isEmpty ? nil : path
        case .webSearch(let search):
            guard search.action == "openPage", let url = search.url, !url.isEmpty else { return nil }
            return url
        case .subAgentActivity(let activity):
            return activity.agentPath.isEmpty ? nil : activity.agentPath
        case .userMessage, .agentMessage, .reasoning, .plan, .mcpToolCall, .contextCompaction, .other:
            return nil
        }
    }

    public static func unwrapShell(_ command: String) -> String {
        let markers = [" -lc ", " -c "]
        for marker in markers {
            guard let range = command.range(of: marker) else { continue }
            let tail = command[range.upperBound...].trimmingCharacters(in: .whitespaces)
            guard tail.count >= 2, let first = tail.first else { continue }
            guard first == "'" || first == "\"", tail.last == first else { continue }
            let inner = String(tail.dropFirst().dropLast())
            guard !inner.contains(first) else { continue }
            return inner
        }
        return command
    }

    private static func namedFile(in input: JSONValue) -> String? {
        for key in ["file_path", "notebook_path", "filename", "path", "file"] {
            guard let value = input[key]?.stringValue, !value.isEmpty else { continue }
            guard FilePathGuess.looksLikeAFile(value) else { continue }
            return value
        }
        return nil
    }

    private static func text(_ input: JSONValue, _ key: String) -> String? {
        guard let value = input[key]?.stringValue, !value.isEmpty else { return nil }
        return value
    }
}
