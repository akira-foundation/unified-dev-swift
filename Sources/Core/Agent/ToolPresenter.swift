import Foundation

public enum ToolPresenter {
    public static func present(_ use: AgentToolUse, worktree: String = "") -> ToolPresentation {
        present(name: use.name, input: use.input, worktree: worktree)
    }

    public static func present(name: String, input: JSONValue, worktree: String = "") -> ToolPresentation {
        var presentation = shape(name: name, input: input, worktree: worktree)
        if presentation.literal == nil {
            presentation.literal = ToolLiteral.of(name: name, input: input)
        }
        return presentation
    }

    private static func shape(name: String, input: JSONValue, worktree: String) -> ToolPresentation {
        if name.hasPrefix("mcp__") { return mcp(name: name, input: input) }

        switch name {
        case "Read": return read(input)
        case "Write": return write(input)
        case "Edit": return edit(input)
        case "MultiEdit": return multiEdit(input)
        case "NotebookEdit": return notebookEdit(input)
        case "Bash": return bash(input, worktree: worktree)
        case "BashOutput": return bashOutput(input)
        case "KillShell", "KillBash": return killShell(input)
        case "Glob": return glob(input)
        case "Grep": return grep(input)
        case "Task", "Agent": return task(input)
        case "TaskOutput": return taskOutput(input)
        case "TaskStop": return taskStop(input)
        case "SendMessage": return sendMessage(input)
        case "TodoWrite": return todos(input)
        case "WebFetch": return webFetch(input)
        case "WebSearch": return webSearch(input)
        case "SlashCommand": return slashCommand(input)
        case "Skill": return skill(input)
        case "AskUserQuestion": return askUserQuestion(input)
        case "ExitPlanMode": return exitPlanMode(input)
        case "EnterPlanMode": return enterPlanMode(input)
        case "ToolSearch": return toolSearch(input)
        case "ListAgents": return ToolPresentation(
            glyph: "person.2.badge.gearshape",
            label: "List agents",
            detail: "",
            tint: .neutral
        )
        default: return fallback(name: name, input: input)
        }
    }

    private static func read(_ input: JSONValue) -> ToolPresentation {
        let path = input["file_path"]?.stringValue ?? input["notebook_path"]?.stringValue ?? ""
        let file = basename(path)

        var label = "Read"
        if let limit = input["limit"]?.intValue, limit > 0 { label = "Read \(limit) lines" }

        var chips: [ToolChip] = []
        if let named = declaredFile(path) { chips.append(named) }
        if let offset = input["offset"]?.intValue, offset > 0 { chips.append(.code("from \(offset)")) }
        if let pages = input["pages"]?.stringValue { chips.append(.code("p\(pages)")) }

        return ToolPresentation(glyph: "doc.text", label: label, detail: file, tint: .accent, chips: chips)
    }

    private static func write(_ input: JSONValue) -> ToolPresentation {
        let path = input["file_path"]?.stringValue ?? ""
        let file = basename(path)
        let lines = lineCount(input["content"]?.stringValue ?? "")

        var chips: [ToolChip] = []
        if let named = declaredFile(path) { chips.append(named) }
        if lines > 0 { chips.append(.code("\(lines) lines")) }

        return ToolPresentation(
            glyph: "square.and.pencil",
            label: "Write",
            detail: file,
            tint: .positive,
            chips: chips
        )
    }

    private static func edit(_ input: JSONValue) -> ToolPresentation {
        let path = input["file_path"]?.stringValue ?? ""
        let file = basename(path)

        var chips: [ToolChip] = []
        if let named = declaredFile(path) { chips.append(named) }
        if input["replace_all"]?.boolValue == true { chips.append(.code("all")) }

        return ToolPresentation(
            glyph: "pencil.line",
            label: "Edit",
            detail: file,
            tint: .positive,
            chips: chips
        )
    }

    private static func multiEdit(_ input: JSONValue) -> ToolPresentation {
        let path = input["file_path"]?.stringValue ?? ""
        let file = basename(path)
        let count = input["edits"]?.arrayValue?.count ?? 0

        var chips: [ToolChip] = []
        if let named = declaredFile(path) { chips.append(named) }
        if count > 0 { chips.append(.code("\(count) edits")) }

        return ToolPresentation(
            glyph: "pencil.line",
            label: "Edit",
            detail: file,
            tint: .positive,
            chips: chips
        )
    }

    private static func notebookEdit(_ input: JSONValue) -> ToolPresentation {
        let path = input["notebook_path"]?.stringValue ?? ""
        let file = basename(path)

        var chips: [ToolChip] = []
        if let named = declaredFile(path) { chips.append(named) }
        if let mode = input["edit_mode"]?.stringValue { chips.append(.code(mode)) }

        return ToolPresentation(
            glyph: "book.closed",
            label: "Notebook",
            detail: file,
            tint: .positive,
            chips: chips
        )
    }

    private static func bash(_ input: JSONValue, worktree: String) -> ToolPresentation {
        let display = CommandDisplay.of(input["command"]?.stringValue ?? "", worktree: worktree)
        let command = oneLine(display.command)
        let label = input["description"]?.stringValue.map { oneLine($0) } ?? "Bash"

        var chips: [ToolChip] = []
        if input["run_in_background"]?.boolValue == true { chips.append(.code("background")) }

        return ToolPresentation(
            glyph: "terminal",
            label: label.isEmpty ? "Bash" : label,
            detail: command,
            tint: display.leftTheWorkspace ? .warning : .neutral,
            chips: chips,
            detailLead: display.lead
        )
    }

    private static func bashOutput(_ input: JSONValue) -> ToolPresentation {
        let shell = input["bash_id"]?.stringValue ?? input["shell_id"]?.stringValue ?? ""

        var chips: [ToolChip] = []
        if let filter = input["filter"]?.stringValue, !filter.isEmpty { chips.append(.code(filter)) }

        return ToolPresentation(
            glyph: "terminal.fill",
            label: "Shell output",
            detail: shell,
            tint: .neutral,
            chips: chips
        )
    }

    private static func killShell(_ input: JSONValue) -> ToolPresentation {
        let shell = input["shell_id"]?.stringValue ?? input["bash_id"]?.stringValue ?? ""
        return ToolPresentation(
            glyph: "terminal",
            label: "Kill shell",
            detail: shell,
            tint: .negative
        )
    }

    private static func glob(_ input: JSONValue) -> ToolPresentation {
        var chips: [ToolChip] = []
        if let path = input["path"]?.stringValue, !path.isEmpty { chips.append(.code(basename(path))) }

        return ToolPresentation(
            glyph: "magnifyingglass",
            label: "Find files",
            detail: input["pattern"]?.stringValue ?? "",
            tint: .accent,
            chips: chips
        )
    }

    private static func grep(_ input: JSONValue) -> ToolPresentation {
        var chips: [ToolChip] = []
        if let glob = input["glob"]?.stringValue, !glob.isEmpty { chips.append(.code(glob)) }
        if let path = input["path"]?.stringValue, !path.isEmpty { chips.append(guessedFile(path)) }

        return ToolPresentation(
            glyph: "text.magnifyingglass",
            label: "Search",
            detail: input["pattern"]?.stringValue ?? "",
            tint: .accent,
            chips: chips
        )
    }

    private static func toolSearch(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "wrench.adjustable",
            label: "Find tools",
            detail: oneLine(input["query"]?.stringValue ?? ""),
            tint: .neutral
        )
    }

    private static func task(_ input: JSONValue) -> ToolPresentation {
        let type = input["subagent_type"]?.stringValue ?? "agent"
        var chips: [ToolChip] = []
        if let model = input["model"]?.stringValue { chips.append(.code(model)) }
        if let isolation = input["isolation"]?.stringValue { chips.append(.code(isolation)) }

        return ToolPresentation(
            glyph: "person.2",
            label: "Agent: \(type)",
            detail: oneLine(input["description"]?.stringValue ?? ""),
            tint: .warning,
            chips: chips
        )
    }

    private static func taskOutput(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "person.2.wave.2",
            label: "Agent output",
            detail: input["task_id"]?.stringValue ?? input["agent_id"]?.stringValue ?? "",
            tint: .warning
        )
    }

    private static func taskStop(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "person.2.slash",
            label: "Stop agent",
            detail: input["task_id"]?.stringValue ?? input["agent_id"]?.stringValue ?? "",
            tint: .negative
        )
    }

    private static func crew(tool: String, input: JSONValue) -> ToolPresentation? {
        switch tool {
        case CrewToolName.start:
            return crewRow(
                glyph: "person.badge.plus",
                label: "Start subagent",
                name: input["name"]?.stringValue ?? "",
                tint: .warning
            )

        case CrewToolName.say:
            return crewRow(
                glyph: "bubble.left.and.bubble.right",
                label: "Say to",
                name: input["to"]?.stringValue ?? "",
                tint: .warning
            )

        case CrewToolName.list:
            return ToolPresentation(
                glyph: "person.3",
                label: "List subagents",
                detail: crewCount(input),
                tint: .neutral
            )

        case CrewToolName.stop:
            return crewRow(
                glyph: "stop.circle",
                label: "Stop subagent",
                name: input["name"]?.stringValue ?? "",
                tint: .negative
            )

        default:
            return nil
        }
    }

    private static func crewRow(
        glyph: String, label: String, name: String, tint: ToolTint
    ) -> ToolPresentation {
        let detail = oneLine(name, limit: Crew.nameLimit)
        return ToolPresentation(
            glyph: glyph,
            label: label,
            detail: detail,
            tint: tint,
            literal: detail.isEmpty ? nil : detail
        )
    }

    private static func crewCount(_ input: JSONValue) -> String {
        guard let count = input["count"]?.intValue ?? input["limit"]?.intValue else { return "" }
        return count.formatted()
    }

    private static func sendMessage(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "paperplane",
            label: "Message agent",
            detail: oneLine(input["prompt"]?.stringValue ?? input["message"]?.stringValue ?? ""),
            tint: .warning,
            chips: (input["agent_id"]?.stringValue).map { [ToolChip.code($0)] } ?? []
        )
    }

    private static func todos(_ input: JSONValue) -> ToolPresentation {
        let items = input["todos"]?.arrayValue ?? []
        let done = items.count { $0["status"]?.stringValue == "completed" }
        let active = items.first { $0["status"]?.stringValue == "in_progress" }
        let running = active?["activeForm"]?.stringValue ?? active?["content"]?.stringValue

        var chips: [ToolChip] = []
        if let running, !running.isEmpty { chips.append(.code(oneLine(running, limit: 60))) }

        return ToolPresentation(
            glyph: "checklist",
            label: "Todos",
            detail: "\(items.count) items, \(done) done",
            tint: .neutral,
            chips: chips
        )
    }

    private static func exitPlanMode(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "checkmark.seal",
            label: "Plan ready",
            detail: firstLine(input["plan"]?.stringValue ?? ""),
            tint: .accent
        )
    }

    private static func enterPlanMode(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "list.bullet.clipboard",
            label: "Plan mode",
            detail: oneLine(input["reason"]?.stringValue ?? "Planning before touching anything"),
            tint: .accent
        )
    }

    private static func askUserQuestion(_ input: JSONValue) -> ToolPresentation {
        let questions = input["questions"]?.arrayValue ?? []
        let first = questions.first
        let text = first?["question"]?.stringValue ?? input["question"]?.stringValue ?? ""

        var chips: [ToolChip] = []
        if questions.count > 1 { chips.append(.code("\(questions.count) questions")) }

        return ToolPresentation(
            glyph: "questionmark.bubble",
            label: "Question",
            detail: oneLine(text),
            tint: .warning,
            chips: chips
        )
    }

    private static func slashCommand(_ input: JSONValue) -> ToolPresentation {
        let command = input["command"]?.stringValue ?? ""
        return ToolPresentation(
            glyph: "command",
            label: "Command",
            detail: oneLine(command),
            tint: .neutral
        )
    }

    private static func skill(_ input: JSONValue) -> ToolPresentation {
        let name = input["skill"]?.stringValue ?? input["name"]?.stringValue ?? ""
        return ToolPresentation(
            glyph: "wand.and.stars",
            label: "Skill",
            detail: oneLine(input["args"]?.stringValue ?? ""),
            tint: .accent,
            chips: name.isEmpty ? [] : [.code(name)]
        )
    }

    private static func webFetch(_ input: JSONValue) -> ToolPresentation {
        let url = input["url"]?.stringValue ?? ""
        return ToolPresentation(
            glyph: "globe",
            label: "Fetch",
            detail: host(url),
            tint: .accent
        )
    }

    private static func webSearch(_ input: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "magnifyingglass.circle",
            label: "Web search",
            detail: oneLine(input["query"]?.stringValue ?? ""),
            tint: .accent
        )
    }

    private static func mcp(name: String, input: JSONValue) -> ToolPresentation {
        let parts = name.dropFirst("mcp__".count).components(separatedBy: "__")
        let server = parts.first ?? name
        let bare = parts.dropFirst().joined(separator: "__")
        let tool = parts.dropFirst().joined(separator: " ").replacing("_", with: " ")
        let isUnifiedDev = server == BridgeRegistration.serverName

        if isUnifiedDev, let row = crew(tool: bare, input: input) { return row }

        let label = tool.isEmpty
            ? (isUnifiedDev ? "Unified Dev" : server)
            : "\(isUnifiedDev ? "Unified Dev" : server): \(tool)"
        let glyph = isUnifiedDev ? "square.stack.3d.up" : "puzzlepiece.extension"

        if let path = ToolLiteral.of(name: name, input: input) {
            return ToolPresentation(
                glyph: glyph,
                label: label,
                detail: basename(path),
                tint: .neutral,
                chips: [.file(path: path)]
            )
        }

        return ToolPresentation(
            glyph: glyph,
            label: label,
            detail: firstScalar(input),
            tint: .neutral
        )
    }

    private static func fallback(name: String, input: JSONValue) -> ToolPresentation {
        if let path = ToolLiteral.of(name: name, input: input) {
            return ToolPresentation(
                glyph: "wrench.and.screwdriver",
                label: name,
                detail: basename(path),
                tint: .neutral,
                chips: [.file(path: path)]
            )
        }

        return ToolPresentation(
            glyph: "wrench.and.screwdriver",
            label: name,
            detail: firstScalar(input),
            tint: .neutral
        )
    }

    private static func declaredFile(_ path: String) -> ToolChip? {
        guard !path.isEmpty else { return nil }
        guard FilePathGuess.isWellFormed(path) else { return .code(oneLine(path, limit: 60)) }
        return .file(path: path)
    }

    private static func guessedFile(_ path: String) -> ToolChip {
        FilePathGuess.looksLikeAFile(path) ? .file(path: path) : .code(basename(path))
    }

    public static func basename(_ path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let last = trimmed.split(separator: "/").last else { return trimmed }
        return String(last)
    }

    public static func oneLine(_ text: String, limit: Int = 300) -> String {
        var out = ""
        out.reserveCapacity(min(text.utf8.count, limit + 1))
        var written = 0
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                pendingSpace = !out.isEmpty
                continue
            }
            if pendingSpace {
                out.append(" ")
                written += 1
                pendingSpace = false
            }
            out.append(character)
            written += 1
            if written >= limit { return out + "\u{2026}" }
        }
        return out
    }

    public static func firstLine(_ text: String) -> String {
        oneLine(text.prefix(while: { $0 != "\n" }).description)
    }

    public static func host(_ url: String) -> String {
        guard let parsed = URL(string: url) else { return oneLine(url) }
        return parsed.host() ?? oneLine(url)
    }

    public static func lineCount(_ text: String) -> Int {
        Git.countLines(text)
    }

    public static func firstScalar(_ input: JSONValue) -> String {
        guard let object = input.objectValue else { return scalar(input) ?? "" }
        for key in object.keys.sorted() {
            if let value = object[key], let text = scalar(value) { return text }
        }
        return ""
    }

    private static func scalar(_ value: JSONValue) -> String? {
        switch value {
        case .string(let text): return text.isEmpty ? nil : oneLine(text)
        case .integer(let number): return String(number)
        case .number(let number):
            guard number == number.rounded(), let exact = Int(exactly: number) else {
                return String(number)
            }
            return String(exact)
        case .bool(let flag): return flag ? "true" : "false"
        case .null, .array, .object: return nil
        }
    }
}
