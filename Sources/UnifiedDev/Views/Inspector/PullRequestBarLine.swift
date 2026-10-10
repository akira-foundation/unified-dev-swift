import SwiftUI
import Core

struct PullRequestBarLine: View {
    var standing: PullRequestStanding
    var branchActions: BranchActionAvailability
    var isWorking: Bool
    var mergeMethod: GitHub.MergeMethod
    var canMerge: Bool
    var worktree: String
    var onChooseMergeMethod: (GitHub.MergeMethod) -> Void
    var onAct: (PullRequestStanding.Act) -> Void

    private var github: GitHubAvailability.State { GitHubAvailability.shared.state }

    var body: some View {
        HStack(spacing: InspectorLayout.tight) {
            substance
            Spacer(minLength: Metrics.spacingSmall)
            trailing
        }
        .task { await GitHubAvailability.shared.check() }
    }

    private var substance: some View {
        HStack(spacing: InspectorLayout.tight) {
            if let number = standing.number, let url = standing.url {
                PullRequestBadge(number: number, title: standing.headline, url: url)
            }

            Text(standing.headline)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(standing.number == nil ? .head : .tail)
                .layoutPriority(-1)

            if let target = standing.target {
                Image(systemName: "arrow.right")
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
                Text(target)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }

            if let ahead = standing.ahead {
                Text(ahead)
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize()
                    .accessibilityLabel(standing.aheadAnnouncement ?? ahead)
            }

            state
        }
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private enum Aside: Equatable {
        case state(String)
        case connectGitHub
        case note(String)
        case nothing
    }

    private var aside: Aside {
        if let text = standing.state { return .state(text) }
        if !github.isUsable { return .connectGitHub }
        if let note = standing.note { return .note(note) }
        return .nothing
    }

    @ViewBuilder
    private var state: some View {
        switch aside {
        case .state(let text):
            HStack(spacing: Metrics.spacingSmall) {
                Circle()
                    .fill(standing.tone.badgeColour)
                    .frame(width: Metrics.dot, height: Metrics.dot)
                    .accessibilityHidden(true)
                Text(text)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            .fixedSize()

        case .connectGitHub:
            Button("Connect GitHub") { GitHubSignIn.shared.present(directory: worktree) }
                .linkButton()
                .font(Typo.caption)
                .fixedSize()
                .help(
                    github == .notInstalled
                        ? "The gh command is not installed, so Unified Dev cannot tell whether this"
                            + " branch has a pull request."
                        : "The GitHub CLI is signed out, so Unified Dev cannot tell whether this"
                            + " branch has a pull request."
                )

        case .note(let note):
            Text(note)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)

        case .nothing:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch slot {
        case .working:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Working")

        case .acting(let button):
            action(button)
                .disabled(!branchActions.isAllowed)

        case .nothing:
            EmptyView()
        }
    }

    private enum Slot: Equatable {
        case working
        case acting(PullRequestStanding.Button)
        case nothing
    }

    private var slot: Slot {
        if isWorking { return .working }
        if let button = standing.button { return .acting(button) }
        return .nothing
    }

    @ViewBuilder
    private func action(_ button: PullRequestStanding.Button) -> some View {
        if button.act == .merge {
            MergeSplitButton(
                label: button.label,
                method: mergeMethod,
                canMerge: canMerge,
                help: branchActions.reason ?? button.sentence,
                choose: onChooseMergeMethod,
                merge: { onAct(.merge) }
            )
        } else {
            Button(button.label) { onAct(button.act) }
                .inspectorBarControl()
                .fixedSize()
                .help(branchActions.reason ?? button.sentence)
        }
    }

    private var helpText: String {
        [branchActions.reason, standing.sentence].compactMap { $0 }.joined(separator: "\n")
    }

    private var accessibilityText: String {
        [
            standing.number.map { "Pull request \($0), \(standing.headline)" } ?? standing.headline,
            standing.target.map { "targeting \($0)" },
            standing.aheadAnnouncement,
            standing.state,
            standing.note,
        ].compactMap { $0 }.joined(separator: ", ")
    }
}
