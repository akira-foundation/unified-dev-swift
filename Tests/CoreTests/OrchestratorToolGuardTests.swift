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
        "git pull",
        "git branch -D old",
        "git worktree add ../x",
        "git tag v1",
        "FOO=1 git commit -am x",
        "env git commit -am x",
        "/bin/zsh -lc 'git commit -am x'",
        "bash -c \"rm -rf build\"",
        "(rm x)",
        "sed --in-place 's/a/b/' f",
        "perl -pi -e 's/a/b/' f",
        "/bin/rm file",
        "unlink file",
        "chmod +x run.sh",
        "echo hi 2> log.txt",
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
        "awk '$3 > 100' data.txt",
        "gh pr list --json number --jq '.[] | select(.number > 1)'",
        "git log --format='%h > %s'",
        "echo \"a && git commit\"",
        "git stash list",
        "git stash show -p",
        "git apply --check fix.patch",
        "git branch --show-current",
        "git tag --list",
        "git worktree list",
        "ls 1>&2",
        "make 2>/dev/stderr",
        "git tag --contains HEAD",
        "git tag --points-at HEAD",
        "git tag --merged main",
        "perl -Mstrict -wle 'print 1'",
        "perl -MFile::Find -e 'print 1'",
    ])
    func readsPass(_ text: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: "Bash", input: command(text)) == nil)
    }

    @Test("tools it does not know, and the bridge's terminal tools, are refused", arguments: [
        "delete_file", "edit_file", "Grok.edit", "Permissions",
        "mcp__unifieddev-workspace-bridge__terminal_start",
        "mcp__unifieddev-workspace-bridge__terminal_write",
        "mcp__unifieddev-workspace-bridge__terminal_send_key",
    ])
    func unknownToolsAreRefused(_ tool: String) {
        #expect(OrchestratorToolGuard.refusal(toolName: tool, input: .object([:])) != nil)
    }

    @Test("a stored approval never answers a shell command in an orchestrator")
    func storedApprovals() {
        #expect(!OrchestratorToolGuard.appliesStoredApprovals(toolName: "Bash", orchestrates: true))
        #expect(!OrchestratorToolGuard.appliesStoredApprovals(toolName: "Shell", orchestrates: true))
        #expect(OrchestratorToolGuard.appliesStoredApprovals(toolName: "WebFetch", orchestrates: true))
        #expect(!OrchestratorToolGuard.appliesStoredApprovals(toolName: "mcp__github__merge_pull_request", orchestrates: true))
        #expect(OrchestratorToolGuard.appliesStoredApprovals(toolName: "Bash", orchestrates: false))
    }

    @Test("tools that only read, and the bridge's own tools, pass",
          arguments: ["Read", "Grep", "Glob", "WebSearch", "TodoWrite", "ExitPlanMode", "AskUserQuestion",
                      "mcp__unifieddev-workspace-bridge__workspace_start", "mcp__github__get_issue"])
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
        #expect(mode == OrchestratorToolGuard.claudeAskingMode)
        #expect(!arguments.contains("--allow-dangerously-skip-permissions"))
        let settings = try #require(arguments.firstIndex(of: "--settings").map { arguments[$0 + 1] })
        let asked = JSONValue.parse(settings)?["permissions"]?["ask"]
        #expect(asked == .array([.string("Bash")]))
    }

    @Test("an orchestrator that asked to plan stays in plan mode")
    func planStays() {
        #expect(OrchestratorToolGuard.claudeMode(.plan, orchestrates: true) == "plan")
        #expect(OrchestratorToolGuard.claudeMode(.bypassPermissions, orchestrates: true) == "default")
        #expect(OrchestratorToolGuard.claudeMode(.bypassPermissions, orchestrates: false) == "bypassPermissions")
    }

    @Test("Grok in an orchestrator neither approves by itself nor runs everything")
    func grokAsks() {
        let meta = GrokClient.sessionMeta(.auto, asksEveryCall: true)
        #expect(meta["yoloMode"]?.boolValue == false)
        #expect(meta["autoMode"]?.boolValue == false)
        #expect(GrokClient.sessionMeta(.auto, asksEveryCall: false)["autoMode"]?.boolValue == true)
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
        let mode = claude.firstIndex(of: "--permission-mode").map { claude[$0 + 1] }
        #expect(mode == OrchestratorToolGuard.claudeAskingMode)
        let settings = claude.firstIndex(of: "--settings").map { claude[$0 + 1] } ?? ""
        #expect(JSONValue.parse(settings)?["permissions"]?["ask"] != nil)

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
