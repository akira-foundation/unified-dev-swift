import SwiftUI
import Core

struct InspectorTabStripGallery: View {
    let app: AppModel

    private static let column: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            row(
                "No pull request",
                "Nothing pushed, nothing to check. Two segments.",
                pullRequest: nil
            )
            row(
                "A pull request with no checks",
                "A repository with no workflows. GitHub reported no runs, so there is still nothing to show.",
                pullRequest: Self.pullRequest(checks: .none, summary: "No checks")
            )
            row(
                "A pull request with checks",
                "GitHub reported runs, so the segment is there, last in the strip.",
                pullRequest: Self.pullRequest(checks: .passing, summary: "12 checks passed")
            )
            row(
                "A pull request whose checks are failing",
                "The same strip. What the pane says is the pane's business.",
                pullRequest: Self.pullRequest(checks: .failing, summary: "1 required check failed")
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(app)
    }

    private func row(
        _ title: String, _ note: String, pullRequest: PullRequest?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            Text(note)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Metrics.spacing) {
                InspectorViewPicker(model: model(pullRequest: pullRequest))
                Spacer(minLength: InspectorLayout.gap)
                InspectorToolbar.GroupingButton(model: model(pullRequest: pullRequest))
                InspectorToolbar.ScopeMenu(model: model(pullRequest: pullRequest))
                InspectorToolbar.MoreMenu(model: model(pullRequest: pullRequest))
            }
                .frame(width: Self.column)
                .background(Palette.surface)
                .overlay(alignment: .bottom) { Hairline() }
        }
    }

    private static func pullRequest(
        checks: PullRequest.Checks, summary: String
    ) -> PullRequest {
        PullRequest(
            number: 42,
            title: "Hide the checks tab when there is nothing to check",
            url: "https://github.com/akira-io/unifieddev/pull/42",
            state: "OPEN",
            checks: checks,
            checksSummary: summary,
            branch: "fix/checks-tab-gate"
        )
    }

    private func model(pullRequest: PullRequest?) -> WorkspaceModel {
        let model = WorkspaceModel(
            workspace: Workspace(
                repoID: RepoID("r1"),
                name: "checks-tab",
                branch: "fix/checks-tab-gate",
                path: "/tmp/unifieddev-snapshot/checks-tab",
                baseBranch: "main"
            ),
            app: app
        )
        model.pullRequest = pullRequest
        model.changedFiles = [
            ChangedFile(path: "Sources/Core/InspectorTab.swift", change: .added, additions: 63),
            ChangedFile(path: "Sources/UnifiedDev/State/WorkspaceModel.swift", change: .modified, additions: 12, deletions: 6),
            ChangedFile(path: "Sources/UnifiedDev/Views/Inspector/InspectorToolbar.swift", change: .modified, additions: 6, deletions: 2),
            ChangedFile(path: "Sources/UnifiedDev/Design/InspectorTabStripGallery.swift", change: .added, additions: 104),
            ChangedFile(path: "Tests/CoreTests/InspectorTabTests.swift", change: .added, additions: 98),
        ]
        return model
    }
}

extension Gallery {
    static let inspectorTabs = Gallery(
        name: "inspector-tabs",
        title: "Inspector tabs",
        size: CGSize(width: 460, height: 470),
        needsFocus: false,
        view: { app in AnyView(InspectorTabStripGallery(app: app)) }
    )
}
