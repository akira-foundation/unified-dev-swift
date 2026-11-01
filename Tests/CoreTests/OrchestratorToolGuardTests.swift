import Foundation
import Testing
@testable import Core

@Suite("Orchestrator tool guard")
struct OrchestratorToolGuardTests {
    private func command(_ text: String) -> JSONValue { .object(["command": .string(text)]) }

    @Test("file edits are refused whatever agent names them",
          arguments: ["Edit", "Write", "MultiEdit", "NotebookEdit", "ApplyPatch"])
    func editsAreRefused(_ tool: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: tool, input: .object([:])) != nil)
    }

    @Test("commands that change the repository or write a file are refused", arguments: [
        "git commit -m 'x'",
        "git -C /tmp/w push origin main",
        "git add .",
        "git checkout -- Sources",
        "git reset --hard",
        "git stash push",
        "cd /tmp && git merge feat",
        "echo hi > notes.txt",
        "cat a >> b",
        "sed -i '' 's/a/b/' file.swift",
        "printf x | tee out.txt",
        "rm -rf build",
        "mv a b",
        "cp a b",
        "mkdir docs",
        "touch file",
    ])
    func writesAreRefused(_ text: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: "Bash", input: command(text)) != nil)
        #expect(OrchestratorToolGuard.refusal(toolName: "Shell", input: command(text)) != nil)
    }

    @Test("reading, asking GitHub and talking to the bridge pass", arguments: [
        "git status",
        "git log --oneline -5",
        "git diff main...HEAD",
        "gh issue view 326",
        "gh pr list --search orchestrator",
        "ls -la 2>/dev/null",
        "grep -rn Orchestrator Sources 2>&1 | head",
        "cat README.md",
    ])
    func readsPass(_ text: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: "Bash", input: command(text)) == nil)
    }

    @Test("tools that only read, and the bridge's own tools, pass",
          arguments: ["Read", "Grep", "Glob", "WebSearch", "TodoWrite", "mcp__unifieddev-workspace-bridge__workspace_start"])
    func otherToolsPass(_ tool: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: tool, input: .object([:])) == nil)
    }

    @Test("a mode that would approve writes by itself is brought down to asking")
    func modeIsClamped() {
        #expect(OrchestratorToolGuard.permissionMode(.bypassPermissions) == .auto)
        #expect(OrchestratorToolGuard.permissionMode(.acceptEdits) == .auto)
        #expect(OrchestratorToolGuard.permissionMode(.autoReview) == .auto)
        #expect(OrchestratorToolGuard.permissionMode(.plan) == .plan)
        #expect(OrchestratorToolGuard.permissionMode(.auto) == .auto)
    }

    @Test("Claude is launched with the edits denied, the commits denied and the role explained")
    func claudeArguments() throws {
        let session = Session(workspaceID: WorkspaceID("w"), permissionMode: .bypassPermissions)
        let arguments = AgentRunner.argv(session: session, resume: nil, orchestrates: true)

        let flag = try #require(arguments.firstIndex(of: "--disallowedTools"))
        let list = arguments[flag + 1]
        #expect(list.contains("Edit"))
        #expect(list.contains("Write"))
        #expect(list.contains("Bash(git commit:*)"))
        #expect(!list.contains("mcp__"))
        #expect(arguments.contains(OrchestratorRole.instructions))
        let mode = arguments.firstIndex(of: "--permission-mode").map { arguments[$0 + 1] }
        #expect(mode == PermissionMode.auto.cliValue)
    }

    @Test("an ordinary workspace is launched exactly as before")
    func ordinaryClaude() {
        let session = Session(workspaceID: WorkspaceID("w"), permissionMode: .bypassPermissions)
        let arguments = AgentRunner.argv(session: session, resume: nil)
        #expect(!arguments.contains("--disallowedTools"))
        #expect(!arguments.contains("--append-system-prompt"))
        let mode = arguments.firstIndex(of: "--permission-mode").map { arguments[$0 + 1] }
        #expect(mode == "bypassPermissions")
    }

    @Test("Codex is held to a read only sandbox whatever mode was picked")
    func codexSandbox() {
        let mode = OrchestratorToolGuard.permissionMode(.bypassPermissions)
        #expect(CodexRunner.sandboxMode(for: mode) == .readOnly)
        #expect(CodexRunner.approvalPolicy(for: mode) == .onRequest)
    }

    @Test("the terminal chat carries the same limits for Claude and Codex")
    func interactive() {
        let claude = AgentKind.claudeCode.interactiveArguments(
            prompt: "", sessionID: SessionID("s"), model: "", effort: "",
            permissionMode: .bypassPermissions, orchestrates: true
        ) ?? []
        #expect(claude.contains("--disallowedTools"))
        #expect(claude.contains(OrchestratorRole.instructions))
        #expect(!claude.contains("bypassPermissions"))

        let codex = AgentKind.codex.interactiveArguments(
            prompt: "", sessionID: SessionID("s"), model: "", effort: "",
            permissionMode: .bypassPermissions, orchestrates: true
        ) ?? []
        let sandbox = codex.firstIndex(of: "--sandbox").map { codex[$0 + 1] }
        #expect(sandbox == CodexSandboxMode.readOnly.rawValue)
    }

    @Test("Grok hears the role at the head of a new session's first prompt, and nowhere else")
    func grokPrompt() {
        let first = OrchestratorToolGuard.prompt("Plan the release", orchestrates: true, opensSession: true)
        #expect(first.hasPrefix(OrchestratorRole.instructions))
        #expect(first.hasSuffix("Plan the release"))
        #expect(OrchestratorToolGuard.prompt("Next", orchestrates: true, opensSession: false) == "Next")
        #expect(OrchestratorToolGuard.prompt("Next", orchestrates: false, opensSession: true) == "Next")
    }
}
