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
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            PullRequestBarLine(
                standing: standing,
                branchActions: branchActions,
                isWorking: isWorking,
                mergeMethod: mergeMethod,
                canMerge: canMerge,
                worktree: worktree,
                onChooseMergeMethod: onChooseMergeMethod,
                onAct: onAct
            )

            if !standing.path.isEmpty {
                PullRequestPathView(
                    standing: standing,
                    showsLabels: PullRequestStanding.showsLabels(atWidth: width),
                    onReach: onReach
                )
            }
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
