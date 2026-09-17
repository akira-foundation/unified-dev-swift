import SwiftUI
import Core

struct ChecksView: View {
    let model: WorkspaceModel

    private static let pollInterval = Duration.seconds(20)

    @State private var runs: [CheckRun] = []
    @State private var groups: [CheckRunGroup] = []
    @State private var hasLoaded = false
    @State private var checksUnavailable = false
    @State private var hovered: String?
    @State private var github: GitHubAvailability.State = .unknown
    @State private var reload = 0
    @State private var sender = CheckFailureSender()

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            if !runs.isEmpty {
                summary
                Hairline()
            }
            if runs.isEmpty {
                empty
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: "\(model.workspace.id)|\(reload)") { await poll() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.runs) { run in
                            row(run)
                        }
                    } header: {
                        header(group)
                    }
                }
            }
            .padding(.bottom, Metrics.spacingSmall)
        }
    }

    private func row(_ run: CheckRun) -> some View {
        var onSend: (@MainActor () -> Void)?
        if CheckFailureSender.canSend(run), model.activeSession != nil {
            onSend = { send(run) }
        }

        return CheckRunRow(
            run: run,
            isHovered: hovered == run.id,
            isSending: sender.isSending(run),
            onSend: onSend
        )
            .rowBackground(isSelected: false, isHovered: hovered == run.id)
            .padding(.horizontal, Metrics.spacingSmall)
            .onHoverChange { hovering in
                hovered = hovering ? run.id : (hovered == run.id ? nil : hovered)
            }
    }

    private var summary: some View {
        let rollup = GitHub.rollup(runs)
        return HStack(spacing: InspectorLayout.gap) {
            Circle()
                .fill(color(for: rollup.0))
                .frame(width: Metrics.dot, height: Metrics.dot)
                .accessibilityHidden(true)
            Text(summaryText(rollup.1))
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text("\(runs.count)")
                .font(Typo.micro)
                .monospacedDigit()
                .foregroundStyle(Palette.textTertiary)
                .accessibilityLabel("\(runs.count) checks")
        }
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
    }

    private var empty: some View {
        emptyContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private enum EmptyReason {
        case cannotAsk
        case unreadable
        case none
        case loading
    }

    private var emptyReason: EmptyReason {
        if !github.isUsable { return .cannotAsk }
        if checksUnavailable { return .unreadable }
        if hasLoaded { return .none }
        return .loading
    }

    @ViewBuilder
    private var emptyContent: some View {
        switch emptyReason {
        case .cannotAsk:
            EmptyStateView(
                glyph: "questionmark.circle",
                title: github == .notInstalled ? "The GitHub CLI is not installed" : "GitHub is not connected",
                message: github == .notInstalled
                    ? "Checks come from GitHub through the gh command, and it is not on this Mac."
                    : "Checks come from GitHub through the gh command, and it is signed out.",
                actionTitle: github == .notInstalled ? "Install the GitHub CLI" : "Connect GitHub",
                action: { GitHubSignIn.shared.run(directory: model.workspace.path) { reload += 1 } }
            )
        case .unreadable:
            EmptyStateView(
                glyph: "lock",
                title: "Checks unavailable",
                message: "GitHub did not let this token read check runs. A fine-grained personal "
                    + "access token cannot be given that permission, so their results are unknown."
            )
        case .none:
            EmptyStateView(
                glyph: "checkmark.seal",
                title: "No checks",
                message: "GitHub has not reported a check run for this branch."
            )
        case .loading:
            LoadingView("Asking GitHub")
        }
    }

    private func header(_ group: CheckRunGroup) -> some View {
        HStack(spacing: Metrics.spacingSmall) {
            Text(group.workflow)
                .font(Typo.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text("\(group.runs.count)")
                .font(Typo.micro)
                .monospacedDigit()
        }
        .foregroundStyle(Palette.textTertiary)
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceSunken)
    }

    private func summaryText(_ rollup: String) -> String {
        if !github.isUsable { return github == .notInstalled ? "No GitHub CLI" : "GitHub not connected" }
        return runs.isEmpty && !hasLoaded ? "Loading checks" : rollup
    }

    private func color(for checks: PullRequest.Checks) -> Color {
        switch checks {
        case .passing: Palette.positive
        case .failing: Palette.negative
        case .pending: Palette.warning
        case .none, .unavailable: Palette.textTertiary
        }
    }

    private func send(_ run: CheckRun) {
        Task {
            guard let failure = await sender.send(run, in: model) else { return }
            app.alert = AppAlert(
                title: "That check was not sent to the agent", message: failure
            )
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            let state = await GitHubAvailability.shared.check()
            github = state

            if state == .ready {
                let found = await GitHubBridge.checks(for: model.workspace)
                checksUnavailable = found == nil
                runs = found ?? []
                groups = CheckRunGroup.build(from: runs)
            }
            hasLoaded = true
            try? await Task.sleep(for: Self.pollInterval)
        }
    }
}
