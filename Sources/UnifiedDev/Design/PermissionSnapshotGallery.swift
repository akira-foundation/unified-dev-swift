import SwiftUI
import Core

struct PermissionSnapshotGallery: View {
    enum Length: String, CaseIterable {
        case short
        case moderate
        case long

        var command: String {
            switch self {
            case .short:
                "./vendor/bin/pest --parallel"
            case .moderate:
                "gh api repos/akira-io/laravel-webhook-server/commits/"
                    + "$(gh pr view 168 --json headRefOid -q .headRefOid)/check-runs "
                    + "--jq '.check_runs[] | {name, conclusion}'"
            case .long:
                (1...12).map {
                    "git log --oneline --since='\($0) days ago' --author='freek' "
                        + "--pretty=format:'%h %s' -- Sources/Core/File\($0).swift"
                }.joined(separator: " && ")
            }
        }
    }

    private func ask(_ length: Length) -> PermissionAsk {
        PermissionAsk(
            requestID: "req-\(length.rawValue)",
            toolName: "Bash",
            input: .object(["command": .string(length.command)]),
            reason: "This command requires approval",
            suggestions: [
                PermissionSuggestion(
                    type: "addRules",
                    behavior: "allow",
                    rules: [PermissionRule(toolName: "Bash", ruleContent: "./vendor/bin/pest --parallel")]
                ),
            ]
        )
    }

    private var home: TranscriptHome {
        TranscriptHome(workspaceID: WorkspaceID("w1"), worktree: "/tmp/nowhere")
    }

    private func toolRow(_ id: String, name: String, file: String) -> some View {
        let use = AgentToolUse(id: id, name: name, input: .object(["file_path": .string(file)]))
        return ToolRowView(
            use: use,
            presentation: TranscriptPresenter.present(use),
            home: home,
            result: nil,
            isError: false,
            refusal: nil,
            durationMS: 1200,
            isExpanded: false,
            onToggle: {}
        )
    }

    private func slice(
        _ title: String,
        length: Length = .short,
        decision: String?,
        note: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 0) {
                toolRow("t1-\(title)", name: "Read", file: "/tmp/app/tests/PassTest.php")
                PermissionAskRowView(
                    ask: ask(length),
                    decision: decision,
                    note: note,
                    projectName: "laravel-mobile-pass"
                )
                toolRow("t2-\(title)", name: "Read", file: "/tmp/app/src/Pass.php")
            }
            .padding(.horizontal, TranscriptLayout.inset)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            slice("One line", length: .short, decision: nil)
            slice("Wrapped", length: .moderate, decision: nil)
            slice("Long and wrapped", length: .long, decision: nil)
            slice("Always allowed", decision: "allow-project")
            slice("Denied", decision: "deny")
        }
        .padding(20)
        .background(Palette.windowBackground)
    }
}
