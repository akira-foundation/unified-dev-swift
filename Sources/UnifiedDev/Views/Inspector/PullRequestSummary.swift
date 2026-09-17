import SwiftUI
import AppKit
import Core

struct PullRequestSummary: View {
    var pullRequest: PullRequest
    var baseBranch: String
    var worktree: String
    var localWork: LocalWork?
    var isWorking: Bool
    var branchActions: BranchActionAvailability
    var mergeMethod: GitHub.MergeMethod
    var onChooseMergeMethod: (GitHub.MergeMethod) -> Void
    var onMerge: (GitHub.MergeMethod) -> Void
    var onMarkReadyForReview: () -> Void
    var onPush: () -> Void
    var onFixConflicts: () -> Void
    var onContinue: () -> Void
    var onArchive: () -> Void
    @Binding var archiveRequest: ArchiveRequest?
    var onConfirmArchive: (ArchiveRequest) -> Void

    @State private var pendingMerge: GitHub.MergeMethod?

    private static let deletesBranch = true

    private var status: PullRequestStatus { pullRequest.status(local: localWork) }

    private var isPending: Bool { pullRequest.isOpen }

    var body: some View {
        HStack(alignment: .center, spacing: InspectorLayout.gap) {
            headline
            trailing
        }
        .contextMenu {
            Button("Open on GitHub") { GitHubBridge.open(pullRequest.url) }
            Button("Copy link", action: copyLink)
            if let url = URL(string: pullRequest.url) {
                ShareLink(item: url) { Text("Share") }
            }
        }
        .onChange(of: canConfirmMerge) { _, available in
            if !available { pendingMerge = nil }
        }
        .onChange(of: branchActions.isAllowed) { _, allowed in
            if !allowed { dismissConfirmation() }
        }
        .onChange(of: worktree) { _, _ in dismissConfirmation() }
        .onChange(of: pullRequest.url) { _, _ in dismissConfirmation() }
    }

    private var identity: some View {
        HStack(spacing: InspectorLayout.tight) {
            PullRequestBadge(
                number: pullRequest.number,
                title: pullRequest.title,
                url: pullRequest.url
            )
            if pullRequest.isDraft { draftChip }
        }
        .fixedSize()
    }

    private var draftChip: some View {
        Text("Draft")
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .help("This pull request is still a draft, so it cannot be merged.")
            .accessibilityLabel("Draft")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Label(status.text, systemImage: status.tone.symbol)
                .font(isPending ? Typo.heading : Typo.title)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: InspectorLayout.tight) {
                PullRequestBadge(
                    number: pullRequest.number,
                    title: pullRequest.title,
                    url: pullRequest.url
                )

                if pullRequest.isDraft { draftChip }

                if let detail = detailLine {
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var detailLine: String? {
        branchActions.note ?? status.detail
    }

    private var trailing: some View {
        trailingControls
            .disabled(!branchActions.isAllowed)
            .popover(isPresented: Binding(
                get: { pendingMerge != nil },
                set: { if !$0 { pendingMerge = nil } }
            ), arrowEdge: .top) {
                if let method = pendingMerge {
                    MergeConfirmationPopover(
                        pullRequest: pullRequest,
                        baseBranch: baseBranch,
                        localWork: localWork,
                        method: method,
                        deletesBranch: Self.deletesBranch,
                        canMerge: canConfirmMerge,
                        tint: status.tone.fill,
                        onConfirm: {
                            pendingMerge = nil
                            onMerge(method)
                        },
                        onCancel: { pendingMerge = nil }
                    )
                }
            }
    }

    @ViewBuilder
    private var trailingControls: some View {
        if isWorking {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Working")
        } else if pullRequest.isOpen {
            primaryButton
        } else if pullRequest.isMerged {
            HStack(spacing: Metrics.spacingTight) {
                continueButton
                archiveButton
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch status.remedy {
        case .merge: mergeControl
        case .markReadyForReview: markReadyForReviewButton
        case .fixConflicts: fixConflictsButton
        case .commitAndPush, .push: pushButton
        }
    }

    private var continueButton: some View {
        continueControl.labelStyle(.titleAndIcon).fixedSize()
    }

    private var continueControl: some View {
        Button("Continue", systemImage: "chevron.forward.2", action: onContinue)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(
                branchActions.reason
                    ?? "Cut a new branch from \(baseBranch) in this worktree and carry on, "
                        + "keeping this workspace's session, its setup and anything uncommitted."
            )
    }

    private var archiveButton: some View {
        archiveControl.labelStyle(.titleAndIcon).fixedSize()
    }

    private var archiveControl: some View {
        Button("Archive", systemImage: "archivebox", action: onArchive)
            .archiveConfirmation(
                $archiveRequest,
                canConfirm: branchActions.isAllowed && !isWorking,
                tint: status.tone.fill,
                onConfirm: onConfirmArchive
            )
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Metrics.corner))
            .controlSize(.regular)
            .help(
                branchActions.reason
                    ?? "Remove this workspace's worktree. #\(pullRequest.number) is merged, so "
                        + "this asks first only when something here exists nowhere else."
            )
    }

    private var pushButton: some View {
        pushControl.labelStyle(.titleAndIcon).fixedSize()
    }

    private var pushControl: some View {
        Button(pushLabel, systemImage: "arrow.up.circle", action: onPush)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Metrics.corner))
            .controlSize(.regular)
            .help(
                branchActions.reason
                    ?? "Ask this workspace's agent to \(pushLabel.lowercased()) branch "
                        + "\(pullRequest.branch.isEmpty ? "this branch" : pullRequest.branch), so "
                        + "#\(pullRequest.number) is what is on this disk."
            )
    }

    private var pushLabel: String {
        status.remedy == .push ? "Push" : "Commit and push"
    }

    private var markReadyForReviewButton: some View {
        Button("Mark ready for review", action: onMarkReadyForReview)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Metrics.corner))
            .controlSize(.regular)
            .fixedSize()
            .help(
                branchActions.reason
                    ?? "Ask this workspace's agent to mark #\(pullRequest.number) ready for review on GitHub."
            )
    }

    private var fixConflictsButton: some View {
        fixConflictsControl.labelStyle(.titleAndIcon).fixedSize()
    }

    private var fixConflictsControl: some View {
        Button("Fix merge conflicts", systemImage: "wrench.and.screwdriver", action: onFixConflicts)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Metrics.corner))
            .controlSize(.regular)
            .help(
                branchActions.reason
                    ?? "Ask this workspace's agent to bring \(baseBranch) into this worktree and "
                        + "resolve the conflicts here. Nothing is pushed and #\(pullRequest.number)"
                        + " is not merged."
            )
    }

    private var mergeControl: some View {
        MergeSplitButton(
            method: mergeMethod,
            fill: status.tone.fill,
            canMerge: status.canMerge,
            help: blockedReason,
            choose: onChooseMergeMethod,
            merge: { propose(mergeMethod) }
        )
    }

    private func dismissConfirmation() {
        pendingMerge = nil
        archiveRequest = nil
    }

    private var canConfirmMerge: Bool {
        pullRequest.isOpen && status.canMerge && branchActions.isAllowed && !isWorking
    }

    private var blockedReason: String? {
        branchActions.reason ?? status.blockedReason
    }

    private var helpText: String {
        var text = "#\(pullRequest.number) \(pullRequest.title)"
        if let detail = status.detail { text += "\n\(detail)" }
        if let reason = status.blockedReason { text += "\n\(reason)" }
        return text
    }

    private var accessibilityText: String {
        [status.text, status.detail].compactMap { $0 }.joined(separator: ", ")
    }

    private func propose(_ method: GitHub.MergeMethod) {
        GitHubSignIn.shared.run(directory: worktree) { pendingMerge = method }
    }

    private func copyLink() {
        Clipboard.copy(pullRequest.url)
    }

    private var tint: Color? {
        status.tone.color
    }
}
