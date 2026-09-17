import SwiftUI
import Core

struct PullRequestCreator: View {
    var branch: String
    var baseBranch: String
    var isWorking: Bool
    var branchActions: BranchActionAvailability
    var worktree: String
    var hasChanges: Bool
    var continued: ContinuedBranch?
    var action: () -> Void

    private var github: GitHubAvailability.State { GitHubAvailability.shared.state }

    var body: some View {
        HStack(spacing: InspectorLayout.gap) {
            Image(systemName: "arrow.triangle.branch")
                .font(Typo.title)
                .imageScale(.medium)
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingHair) {
                Text(branch)
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .accessibilityLabel("Branch \(branch)")

                if github.isUsable {
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Button("Connect GitHub") {
                        GitHubSignIn.shared.present(directory: worktree)
                    }
                    .linkButton()
                    .font(Typo.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(
                        github == .notInstalled
                            ? "The gh command is not installed, so Unified Dev cannot tell whether this branch has a pull request."
                            : "The GitHub CLI is signed out, so Unified Dev cannot tell whether this branch has a pull request."
                    )
                }
            }
            .layoutPriority(-1)

            Spacer(minLength: Metrics.spacingSmall)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Working")
            } else if hasChanges {
                createButton.labelStyle(.titleOnly).fixedSize()
            }
        }
        .contextMenu {
            Button("Copy Branch Name") { Clipboard.copy(branch) }
        }
        .task { await GitHubAvailability.shared.check() }
    }

    private var subtitle: String {
        if let note = branchActions.note { return note }
        guard hasChanges else { return ContinuedBranch.line(on: branch, continued: continued) }
        return "No pull request yet. Target \(baseBranch)."
    }

    private var createButton: some View {
        Button("Create pull request", systemImage: "arrow.triangle.pull", action: action)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Metrics.corner))
            .tint(Palette.controlAccent)
            .controlSize(.regular)
            .disabled(!branchActions.isAllowed)
            .help(helpText)
    }

    private var helpText: String {
        if let reason = branchActions.reason { return reason }
        return "Ask this workspace's agent to push the branch and open a pull request against "
            + "\(baseBranch), following this project's pull request instructions."
    }
}
