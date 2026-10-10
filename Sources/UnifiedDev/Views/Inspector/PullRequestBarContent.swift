import SwiftUI
import Core

struct PullRequestBarContent: View {
    var standing: PullRequestStanding
    var branchActions: BranchActionAvailability
    var isWorking: Bool
    var mergeMethod: GitHub.MergeMethod
    var canMerge: Bool
    var worktree: String
    var onChooseMergeMethod: (GitHub.MergeMethod) -> Void
    var onAct: (PullRequestStanding.Act) -> Void
    var onReach: (PullRequestReach) -> Void

    @State private var width = Metrics.inspectorWidth

    var body: some View {
        HStack(alignment: .top, spacing: InspectorLayout.gap) {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                PullRequestBarLine(
                    standing: standing,
                    branchActions: branchActions,
                    worktree: worktree
                )

                if !standing.path.isEmpty {
                    PullRequestPathView(
                        standing: standing,
                        showsLabels: PullRequestStanding.showsLabels(atWidth: width),
                        onReach: onReach
                    )
                }
            }

            trailing
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacingWide)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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
}
