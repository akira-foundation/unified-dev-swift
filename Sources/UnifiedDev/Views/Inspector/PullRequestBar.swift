import SwiftUI
import Core

struct PullRequestBar: View {
    let model: WorkspaceModel

    @Environment(AppModel.self) private var app

    private static let pollInterval = Duration.seconds(20)

    @State private var isWorking = false
    @State private var pendingArchive: ArchiveRequest?
    @State private var isVisible = false

    private var report: PullRequestNotice? {
        get { model.pullRequestNotice }
        nonmutating set { model.pullRequestNotice = newValue }
    }

    var body: some View {
        strip
            .task(id: model.workspace.id) { await poll() }
            .onChange(of: model.workspace.id) { _, _ in pendingArchive = nil }
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                pendingArchive = nil
            }
    }

    private var strip: some View {
        content
            .padding(.horizontal, InspectorLayout.inset)
            .padding(.vertical, Metrics.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tint: Color? {
        model.pullRequest?.status(local: model.localWork).tone.color
    }

    private var washOpacity: Double {
        model.pullRequest?.isOpen == false
            ? InspectorLayout.bandOpacityQuiet
            : InspectorLayout.bandOpacity
    }

    @ViewBuilder
    private var content: some View {
        if let pullRequest = model.pullRequest {
            PullRequestSummary(
                pullRequest: pullRequest,
                baseBranch: model.workspace.baseBranch,
                worktree: model.workspace.path,
                localWork: model.localWork,
                isWorking: isWorking,
                branchActions: branchActions,
                mergeMethod: model.mergeMethod,
                onChooseMergeMethod: chooseMergeMethod,
                onMerge: merge,
                onMarkReadyForReview: { markReadyForReview(pullRequest) },
                onPush: push,
                onFixConflicts: { fixConflicts(on: pullRequest) },
                onContinue: { carryOn(after: pullRequest) },
                onArchive: archive,
                archiveRequest: $pendingArchive,
                onConfirmArchive: confirmArchive
            )
        } else {
            PullRequestCreator(
                branch: model.workspace.branch,
                baseBranch: model.workspace.baseBranch,
                isWorking: isWorking || model.isLoadingPullRequest,
                branchActions: branchActions,
                worktree: model.workspace.path,
                hasChanges: hasChanges,
                continued: model.continued,
                action: createPullRequest
            )
        }
    }

    private var branchActions: BranchActionAvailability {
        .mayActOnBranch(
            isAgentBusy: app.isRunning(model.workspace),
            pullRequest: model.pullRequest
        )
    }

    private var hasChanges: Bool {
        !model.changedFiles.isEmpty || model.workspace.hasDiff
    }

    private func chooseMergeMethod(_ method: GitHub.MergeMethod) {
        Task { await model.chooseMergeMethod(method) }
    }

    private func poll() async {
        await model.loadMergeMethod()

        var maxAge = WorkspaceModel.pullRequestArrivalMaxAge
        while !Task.isCancelled {
            await model.refreshPullRequest(maxAge: maxAge)
            maxAge = .zero
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    private func createPullRequest() {
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            if let refusal = await model.requestPullRequest() {
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was sent", message: refusal
                )
            }
        }
    }

    private func markReadyForReview(_ pullRequest: PullRequest) {
        guard !isWorking, branchActions.isAllowed else { return }
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            if let refusal = await model.requestMarkReadyForReview(pullRequest) {
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was sent", message: refusal
                )
            }
        }
    }

    private func push() {
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            if let refusal = await model.requestPush() {
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was sent", message: refusal
                )
            }
        }
    }

    private func fixConflicts(on pullRequest: PullRequest) {
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            if let refusal = await model.requestFixConflicts(pullRequest) {
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was sent", message: refusal
                )
            }
        }
    }

    private func carryOn(after pullRequest: PullRequest) {
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            switch await app.continueAfterMerge(model.workspace, pullRequest: pullRequest) {
            case .continued:
                break
            case .refused(let refusal):
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was changed", message: refusal.sentence
                )
            case .failed(let reason):
                report = PullRequestNotice(
                    tone: .failure,
                    title: "Could not continue",
                    message: reason,
                    details: nil
                )
            }
        }
    }

    private func archive() {
        let workspace = model.workspace
        Task {
            await app.archive(workspace, presentConfirmation: presentArchive)
        }
    }

    private func confirmArchive(_ request: ArchiveRequest) {
        pendingArchive = nil
        Task {
            await app.confirmArchive(request, presentConfirmation: presentArchive)
        }
    }

    private func presentArchive(_ request: ArchiveRequest) {
        guard isVisible, app.selection.workspaceID == request.workspace.id else { return }
        pendingArchive = request
    }

    private func merge(_ method: GitHub.MergeMethod) {
        guard let pullRequest = model.pullRequest else { return }
        isWorking = true
        report = nil

        Task {
            defer { isWorking = false }
            if let refusal = await model.requestMerge(pullRequest, method: method) {
                report = PullRequestNotice(
                    tone: .info, title: "Nothing was sent", message: refusal
                )
            }
        }
    }
}
