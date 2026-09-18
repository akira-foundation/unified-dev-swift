import SwiftUI
import Core

struct SubagentOutputGallery: View {
    var app: AppModel

    private static let home = TranscriptHome(
        workspaceID: WorkspaceID("w1"), worktree: "/Users/you/dev/code/assign"
    )

    var body: some View {
        let transcript = Self.transcript
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text("Tasks 7-8: HTTP layer")
                        .font(Typo.title)
                    Text("general-purpose · 11m")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.block)
                .subagentReadingColumn()

                SubagentConversationView(
                    rows: TranscriptModel.rows(from: transcript.messages),
                    prompt: transcript.prompt,
                    home: Self.home,
                    droppedRows: 0,
                    isRunning: true
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metrics.pane)
        }
        .background(Palette.windowBackground)
        .environment(app)
    }

    private static var transcript: SubagentTranscript {
        SubagentTranscript.parse(lines.joined(separator: "\n"), sessionID: SessionID("gallery"))
    }

    private static let lines = [
        #"{"type":"user","uuid":"u1","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"text","text":"You are implementing Tasks 7 and 8 of a plan for \"Assign\", an internal Asana-style task manager. These add the HTTP layer for projects, initiatives and tasks.\n\n**Working directory: /Users/you/dev/code/assign**\n\nRead the rule files first, then the requirements for both tasks, then the reference controller. Commit each task on its own once its tests pass, and report what changed, what was tested and anything you were unsure of. Do not touch the billing module, which another agent is rewriting in parallel on its own branch."}]}}"#,
        #"{"type":"assistant","uuid":"u2","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"thinking","thinking":"The plan lists the rule files first, so read those before touching a controller."}]}}"#,
        #"{"type":"assistant","uuid":"u3","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"text","text":"**Read first, in this order:**\n\n1. `.ai/rules/index.md`, then every rule file whose globs cover `app/Http/**`.\n2. The requirements for Tasks 7 and 8.\n\nThe reference implementation is `WorkspaceStoreController`, which is *invokable* and returns a redirect."}]}}"#,
        #"{"type":"assistant","uuid":"u4","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_a","name":"Bash","input":{"command":"cd /Users/you/dev/code/assign && grep -rin 'FormRequest' app/Http --include='*.php' | head -40","description":"Find the form requests"}}]}}"#,
        #"{"type":"user","uuid":"u5","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_a","content":"app/Http/Requests/Workspaces/StoreWorkspaceRequest.php:9:class StoreWorkspaceRequest extends FormRequest"}]}}"#,
        #"{"type":"assistant","uuid":"u6","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_b","name":"Read","input":{"file_path":"/Users/you/dev/code/assign/routes/web.php"}}]}}"#,
        #"{"type":"user","uuid":"u7","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_b","content":"     1\t<?php\n     2\t\n     3\tRoute::get('/', HomeController::class);"}]}}"#,
        #"{"type":"assistant","uuid":"u8","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_c","name":"Bash","input":{"command":"cd /Users/you/dev/code/assign && ./vendor/bin/pest --filter=Project","description":"Run the Task 7 suite"}}]}}"#,
        #"{"type":"user","uuid":"u9","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_c","content":"Tests:  23 passed (61 assertions)"}]}}"#,
        #"{"type":"assistant","uuid":"u10","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"text","text":"Both tasks are in, one commit each.\n\n- **Task 7** adds the project and initiative controllers, their form requests and their policies.\n- **Task 8** adds the task controllers and the `my-tasks` grouping.\n\n197 tests green (174 baseline + 23 new), PHPStan clean, Pint clean."}]}}"#,
    ]
}

extension Gallery {
    static let subagentOutput = Gallery(
        name: "subagent-output",
        title: "Subagent output",
        size: CGSize(width: 900, height: 780),
        needsFocus: false,
        view: { app in AnyView(SubagentOutputGallery(app: app)) }
    )
}
