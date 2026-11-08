import SwiftUI
import Core

struct MergeConfirmationPopover: View {
    let pullRequest: PullRequest
    let baseBranch: String
    let localWork: LocalWork?
    let method: GitHub.MergeMethod
    let deletesBranch: Bool
    let canMerge: Bool
    let tint: Color
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ConfirmationPopover(
            title: pullRequest.mergeConfirmationTitle(base: baseBranch),
            confirmLabel: method.label,
            tint: tint,
            canConfirm: canMerge,
            onConfirm: onConfirm,
            onCancel: onCancel
        ) {
            ForEach(pullRequest.mergeWarnings(base: baseBranch, local: localWork), id: \.self) { warning in
                Text(warning)
                    .foregroundStyle(Palette.negative)
            }

            Text(pullRequest.mergeConfirmationMessage)

            if let deletion = pullRequest.mergeBranchDeletionMessage(deletesBranch: deletesBranch) {
                Text(deletion)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MergeConfirmationModifier: ViewModifier {
    @Binding var pending: GitHub.MergeMethod?
    let model: WorkspaceModel
    let canConfirm: Bool
    let arrowEdge: Edge
    let onConfirm: (GitHub.MergeMethod) -> Void

    func body(content: Content) -> some View {
        content
            .popover(isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ), arrowEdge: arrowEdge) {
                if let method = pending, let pullRequest = model.pullRequest {
                    MergeConfirmationPopover(
                        pullRequest: pullRequest,
                        baseBranch: pullRequest.targetBranch(or: model.workspace.baseBranch),
                        localWork: model.localWork,
                        method: method,
                        deletesBranch: true,
                        canMerge: canConfirm,
                        tint: model.pullRequestStanding.tone.pathColour,
                        onConfirm: {
                            pending = nil
                            onConfirm(method)
                        },
                        onCancel: { pending = nil }
                    )
                }
            }
            .onChange(of: model.workspace.id) { _, _ in pending = nil }
            .onChange(of: model.pullRequest?.url) { _, _ in pending = nil }
            .onChange(of: canConfirm) { _, available in
                if !available { pending = nil }
            }
            .onDisappear { pending = nil }
    }
}

extension View {
    func mergeConfirmation(
        _ pending: Binding<GitHub.MergeMethod?>,
        model: WorkspaceModel,
        canConfirm: Bool,
        arrowEdge: Edge,
        onConfirm: @escaping (GitHub.MergeMethod) -> Void
    ) -> some View {
        modifier(MergeConfirmationModifier(
            pending: pending, model: model, canConfirm: canConfirm, arrowEdge: arrowEdge, onConfirm: onConfirm
        ))
    }
}
