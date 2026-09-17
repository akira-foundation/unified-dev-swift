import SwiftUI
import Core

struct ToolRowSnapshotGallery: View {
    private static let longCommand = "gh api repos/akira-io/laravel-webhook-server/commits/"
        + "$(gh pr view 168 --json headRefOid -q .headRefOid)/check-runs "
        + "--jq '.check_runs[] | {name, conclusion}'"

    private static let brief = """
        Read the transcript's row views and work out where the decision is taken that a tool's \
        detail is a literal rather than a sentence. Report the file and the line, and say whether \
        the same rule reaches the block inside an expanded row.

        Do not change anything. This is a question, not a task.
        """

    private static let worktree = "/Users/you/unifieddev/workspaces/there-there/hibiki-sea"

    private var home: TranscriptHome {
        TranscriptHome(workspaceID: WorkspaceID("r1"), worktree: Self.worktree)
    }

    private func row(
        _ id: String,
        _ name: String,
        _ input: [String: JSONValue],
        isExpanded: Bool = false
    ) -> some View {
        let use = AgentToolUse(id: id, name: name, input: .object(input))
        return ToolRowView(
            use: use,
            presentation: TranscriptPresenter.present(use, worktree: home.worktree),
            home: home,
            result: nil,
            isError: false,
            refusal: nil,
            durationMS: 1_200,
            isExpanded: isExpanded,
            onToggle: {}
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            group("Literals, set as code") {
                row("r1", "Bash", [
                    "description": .string("Check check-runs and PR conclusions"),
                    "command": .string(Self.longCommand),
                ])
                row("r2", "Bash", [
                    "description": .string("Run the suite"),
                    "command": .string("./vendor/bin/pest --parallel --filter=WebhookCallTest"),
                ])
                row("r3", "Read", ["file_path": .string("/tmp/app/src/WebhookCall.php")])
                row("r4", "Glob", ["pattern": .string("app/Beacon/**/*.php")])
                row("r5", "Grep", ["pattern": .string("await Git\\.|await Shell\\.")])
                row("r6", "WebFetch", ["url": .string("https://akira-io.com/docs/laravel-webhook-server")])
            }

            group("Prose, left in the reading face") {
                row("p1", "Task", [
                    "subagent_type": .string("Explore"),
                    "description": .string("Find where the transcript decides which rows are code"),
                ])
                row("p2", "WebSearch", ["query": .string("how do I rebase onto a branch that moved")])
                row("p3", "TodoWrite", ["todos": .array([
                    .object(["content": .string("Set the command in mono"), "status": .string("completed")]),
                    .object(["content": .string("Add the copy button"), "status": .string("in_progress")]),
                ])])
                row("p4", "AskUserQuestion", [
                    "question": .string("Should the copy button sit on the row or on the panel?"),
                ])
            }

            group("Where a command ran") {
                row("c1", "Bash", [
                    "description": .string("List admin tests"),
                    "command": .string("cd \(Self.worktree)\nls tests/Http/Admin"),
                ])
                row("c2", "Bash", [
                    "description": .string("Run the api package tests"),
                    "command": .string("cd \(Self.worktree)/packages/api && npm test -- --runInBand"),
                ])
                row("c3", "Bash", [
                    "description": .string("Check the other worktree"),
                    "command": .string("cd /Users/you/unifieddev/workspaces/unifieddev/main && git log --oneline -5"),
                ])
                row("c4", "Bash", [
                    "description": .string("Show the current diff"),
                    "command": .string("git diff --stat"),
                ])
                row("c5", "Bash", [
                    "description": .string("Read the system log"),
                    "command": .string("cd /tmp\ncd /var/log\ntail -n 20 system.log"),
                ])
                row("c6", "Bash", [
                    "description": .string("List the home checkout"),
                    "command": .string("cd ~/unifieddev && ls"),
                ])
            }

            group("Opened, with the block a copy button sits on") {
                row("e1", "Bash", [
                    "description": .string("Check check-runs and PR conclusions"),
                    "command": .string(Self.longCommand),
                ], isExpanded: true)

                row("e2", "Task", [
                    "subagent_type": .string("Explore"),
                    "description": .string("Find where the transcript decides which rows are code"),
                    "prompt": .string(Self.brief),
                ], isExpanded: true)
            }

            group("The other rows on the same ceiling") {
                SessionStartRowView(info: AgentInit(
                    sessionID: "s1",
                    model: "opus-5-1m",
                    permissionMode: "acceptEdits"
                ))
                ThinkingRowView(
                    text: "The gap is the whole complaint: four letters of label, then a "
                        + "hundred and forty seven points of nothing before its own detail."
                )
                row("s1", "Grep", [
                    "pattern": .string("labelWidth|transcriptLabelColumn"),
                    "path": .string("/tmp/app/src/WebhookCall.php"),
                ])
            }
        }
        .frame(width: 760, alignment: .leading)
        .padding(20)
        .background(Palette.windowBackground)
    }

    private func group(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
                .padding(.bottom, 4)
            content()
        }
    }
}
