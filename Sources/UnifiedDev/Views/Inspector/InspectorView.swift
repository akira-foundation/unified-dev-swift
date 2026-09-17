import SwiftUI
import Core

struct InspectorView: View {
    let model: WorkspaceModel

    @Bindable private var signIn = GitHubSignIn.shared

    @State private var fileQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            if let notice = model.pullRequestNotice {
                InspectorNotice(notice: notice) { model.pullRequestNotice = nil }
                Hairline()
            }

            if model.inspectorTab != .checks, model.diffScope.isNarrowed {
                DiffScopeBand(
                    scope: model.diffScope,
                    fileCount: model.changedFiles.count,
                    note: model.scopeNote
                ) {
                    model.setDiffScope(.all)
                }
                Hairline()
            }

            content
                .frame(maxHeight: .infinity)

            if let failure = model.pullRequestRefreshFailure {
                RefreshFailureRow(failure: failure, hasPullRequest: model.pullRequest != nil)
            }

            PullRequestBar(model: model)
        }
        .sheet(item: $signIn.request) { request in
            GitHubSignInSheet(request: request) { connected in
                signIn.finish(connected: connected)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
            guard width >= Metrics.inspectorMinimum else { return }
            InspectorGeometry.shared.setInspectorWidth(width)
        }
        .onDisappear { InspectorGeometry.shared.setInspectorWidth(0) }
        .searchable(text: $fileQuery, placement: .automatic, prompt: "Filter files")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorViewPicker(model: model)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItemGroup(placement: .primaryAction) {
                InspectorToolbar.GroupingButton(model: model)
                InspectorToolbar.ScopeMenu(model: model)
                InspectorToolbar.MoreMenu(model: model)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            if let work = model.localWork, work.unpushedCommits > 0 || work.modifiedFiles > 0 {
                ToolbarItem(placement: .primaryAction) {
                    InspectorToolbar.PushButton(model: model)
                }
            }

            if let pullRequest = model.pullRequest,
               pullRequest.status(local: model.localWork).canMerge {
                ToolbarItem(placement: .primaryAction) {
                    InspectorToolbar.MergeButton(model: model)
                }
            }
        }
        .environment(\.openInRepoID, model.repo?.id)
    }

    @ViewBuilder
    private var content: some View {
        switch model.inspectorTab {
        case .allFiles:
            FileTreeView(model: model, query: $fileQuery)
        case .changes:
            ChangedFileList(model: model, query: $fileQuery)
        case .checks:
            ChecksView(model: model)
        }
    }
}

private struct RefreshFailureRow: View {
    var failure: GitHubReadFailure
    var hasPullRequest: Bool

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: InspectorLayout.gap) {
                Text(failure.summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let transcript = failure.transcript {
                    ScrollView(.horizontal) {
                        Text(transcript)
                            .font(Typo.codeSmall)
                            .foregroundStyle(Palette.textSecondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 140)
                    .padding(InspectorLayout.tight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.cornerSmall))
                }

                if let retryAt = failure.retryAt {
                    Text("Next refresh after \(retryAt.formatted(date: .omitted, time: .shortened))")
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.top, InspectorLayout.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Button {
                isExpanded.toggle()
            } label: {
                Label(
                    hasPullRequest ? "Showing the last GitHub update" : "GitHub could not refresh",
                    systemImage: "exclamationmark.triangle"
                )
                .font(Typo.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacing)
        .accessibilityElement(children: .contain)
    }
}
