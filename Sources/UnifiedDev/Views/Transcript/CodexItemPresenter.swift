import SwiftUI
import Core

enum CodexItemPresenter {
    static func present(_ use: AgentToolUse, worktree: String = "") -> ToolPresentation? {
        guard let item = CodexTranslation.item(in: use.input) else { return nil }
        return present(item, worktree: worktree)
    }

    static func present(_ item: CodexItem, worktree: String = "") -> ToolPresentation {
        var presentation = shape(item, worktree: worktree)
        presentation.literal = ToolLiteral.of(codex: item)
        return presentation
    }

    private static func shape(_ item: CodexItem, worktree: String) -> ToolPresentation {
        switch item {
        case .commandExecution(let run): command(run, worktree: worktree)
        case .fileChange(let change): fileChange(change)
        case .mcpToolCall(let call): mcp(call)
        case .webSearch(let search): webSearch(search)
        case .plan(let plan): self.plan(plan)
        case .subAgentActivity(let activity): subAgent(activity)
        case .contextCompaction: compaction()
        case .other(let type, _, let json): other(type: type, json: json)
        case .userMessage, .agentMessage, .reasoning:
            ToolPresentation(
                glyph: "text.alignleft",
                label: "Message",
                detail: "",
                tint: .neutral
            )
        }
    }

    private static func command(_ run: CodexCommandExecution, worktree: String) -> ToolPresentation {
        let display = CommandDisplay.of(ToolLiteral.unwrapShell(run.command), worktree: worktree)
        let command = ToolPresenter.oneLine(display.command)

        var chips: [ToolChip] = []
        if let code = run.exitCode, code != 0 { chips.append(.code("exit \(code)")) }
        if run.status == .declined { chips.append(.code("declined")) }

        let tint: ToolTint = switch (run.status, display.leftTheWorkspace) {
        case (.failed, _): .negative
        case (_, true): .warning
        default: .neutral
        }

        return ToolPresentation(
            glyph: "terminal",
            label: "Shell",
            detail: command,
            tint: tint,
            chips: chips,
            detailLead: display.lead
        )
    }

    private static func fileChange(_ change: CodexFileChange) -> ToolPresentation {
        let label = change.changes.count == 1
            ? (change.changes[0].kind.label)
            : "Patch"
        let detail = change.changes.count == 1
            ? ToolPresenter.basename(change.changes[0].path)
            : "\(change.changes.count) files"

        var chips: [ToolChip] = []
        if change.changes.count == 1 {
            chips.append(.file(path: change.changes[0].path))
        }
        if change.status == .declined { chips.append(.code("declined")) }

        return ToolPresentation(
            glyph: glyph(for: change),
            label: label,
            detail: detail,
            tint: tint(for: change.status),
            chips: chips
        )
    }

    private static func glyph(for change: CodexFileChange) -> String {
        guard change.changes.count == 1 else { return "square.stack.3d.up" }
        switch change.changes[0].kind {
        case .add: return "doc.badge.plus"
        case .delete: return "trash"
        case .update(let movedTo): return movedTo == nil ? "pencil.line" : "arrow.right.doc.on.clipboard"
        case .unknown: return "doc"
        }
    }

    private static func tint(for status: CodexRunStatus) -> ToolTint {
        switch status {
        case .failed: .negative
        case .declined: .neutral
        default: .positive
        }
    }

    private static func mcp(_ call: CodexMcpToolCall) -> ToolPresentation {
        let tool = call.tool.replacing("_", with: " ")
        return ToolPresentation(
            glyph: "puzzlepiece.extension",
            label: tool.isEmpty ? call.server : "\(call.server): \(tool)",
            detail: call.errorMessage ?? "",
            tint: call.status == .failed ? .negative : .neutral
        )
    }

    private static func webSearch(_ search: CodexWebSearch) -> ToolPresentation {
        switch search.action {
        case "openPage":
            return ToolPresentation(
                glyph: "safari",
                label: "Open page",
                detail: search.url ?? search.query,
                tint: .neutral
            )
        case "findInPage":
            return ToolPresentation(
                glyph: "text.magnifyingglass",
                label: "Find in page",
                detail: search.query,
                tint: .neutral
            )
        default:
            return ToolPresentation(
                glyph: "magnifyingglass",
                label: "Search the web",
                detail: search.query,
                tint: .neutral
            )
        }
    }

    private static func plan(_ plan: CodexPlan) -> ToolPresentation {
        ToolPresentation(
            glyph: "list.bullet.rectangle",
            label: "Plan",
            detail: ToolPresenter.oneLine(firstLine(of: plan.text)),
            tint: .neutral
        )
    }

    private static func subAgent(_ activity: CodexSubAgentActivity) -> ToolPresentation {
        ToolPresentation(
            glyph: "person.2",
            label: "Sub-agent",
            detail: ToolPresenter.basename(activity.agentPath),
            tint: .neutral,
            chips: activity.kind.isEmpty ? [] : [.code(activity.kind)]
        )
    }

    private static func compaction() -> ToolPresentation {
        ToolPresentation(
            glyph: "arrow.down.right.and.arrow.up.left",
            label: "Compacted the conversation",
            detail: "",
            tint: .neutral
        )
    }

    private static func other(type: String, json: JSONValue) -> ToolPresentation {
        ToolPresentation(
            glyph: "questionmark.square.dashed",
            label: spaced(type),
            detail: ToolPresenter.oneLine(summary(of: json)),
            tint: .neutral
        )
    }

    static func spaced(_ type: String) -> String {
        var out = ""
        for character in type {
            if character.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(out.isEmpty ? Character(character.uppercased()) : character)
        }
        return out
    }

    static func summary(of json: JSONValue) -> String {
        for key in ["path", "query", "command", "text", "tool", "prompt"] {
            if let value = json[key]?.stringValue, !value.isEmpty { return value }
        }
        return ""
    }

    static func firstLine(of text: String) -> String {
        text.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    }
}

enum TranscriptPresenter {
    static func present(_ use: AgentToolUse, worktree: String = "") -> ToolPresentation {
        CodexItemPresenter.present(use, worktree: worktree) ?? ToolPresenter.present(use, worktree: worktree)
    }

    static func present(name: String, input: JSONValue, worktree: String = "") -> ToolPresentation {
        if let item = CodexTranslation.item(in: input) {
            return CodexItemPresenter.present(item, worktree: worktree)
        }
        return ToolPresenter.present(name: name, input: input, worktree: worktree)
    }
}
