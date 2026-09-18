import SwiftUI
import Core

struct ArchivedWorkspaceView: View {
    @Bindable var model: WorkspaceModel

    @Environment(AppModel.self) private var app

    @State private var source: RestoreSource?
    @State private var isLocating = true

    @State private var carryOn: CarryOnDecision?

    @AppStorage(ChatTextSize.defaultsKey) private var textSize = ChatTextSize.defaultChoice
    @AppStorage(ChatFont.defaultsKey) private var chatFontID = ChatFont.standardID
    @AppStorage(ChatLineHeight.defaultsKey) private var lineHeight = ChatLineHeight.defaultChoice

    private var workspace: Workspace { model.workspace }

    var body: some View {
        VStack(spacing: 0) {
            banner
            if model.sessions.count > 1 {
                sessions
            }
            TranscriptView(transcript: model.activeTranscript)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.fontScale, textSize.scale)
                .environment(\.chatFont, ChatFont(rawValue: chatFontID))
                .environment(\.chatLineHeight, lineHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: workspace.id) { await model.reloadSessions() }
        .task(id: workspace.id) { await locateBranch() }
        .task(id: carryOnKey) { await decideCarryOn() }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
                Image(systemName: "archivebox")
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    Text(workspace.name)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: Metrics.spacingWide)

                controls
            }

            standing
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let repo = model.repo { parts.append(repo.name) }
        parts.append(workspace.branch)
        if let archivedAt = workspace.archivedAt {
            parts.append(
                "archived " + archivedAt.formatted(
                    .relative(presentation: .named, unitsStyle: .wide)
                )
            )
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var controls: some View {
        HStack(spacing: Metrics.spacing) {
            Button("Copy Branch Name") { Clipboard.copy(workspace.branch) }

            if let plan = carryOn?.plan {
                Button("Carry On") {
                    Task { await app.carryOn(workspace, plan: plan) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .disabled(isCarryingOn)
                .help(carryOnHelp(plan))
            } else {
                Button("Restore Workspace") {
                    Task { await app.restore(workspace) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .disabled(isRestoring || isLocating || source?.canRebuild != true)
                .help(restoreHelp)
            }

            if isRestoring || isCarryingOn || isLocating {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var isRestoring: Bool { app.restoring.contains(workspace.id) }

    private var isCarryingOn: Bool { app.carryingOn.contains(workspace.id) }

    private func carryOnHelp(_ plan: CarryOnPlan) -> String {
        "Cuts a new worktree from \(plan.baseBranch), on \(plan.branch), and picks this "
            + "conversation up there with the agent's memory of it intact. This archive is left "
            + "as it is."
    }

    private var restoreHelp: String {
        guard let source else { return "Looking for the branch" }
        return source.explanation(branch: workspace.branch)
    }

    @ViewBuilder
    private var standing: some View {
        HStack(alignment: .top, spacing: Metrics.spacingWide) {
            Image(systemName: symbol)
                .font(Typo.caption)
                .foregroundStyle(tone)
                .accessibilityHidden(true)
            Text(sentence)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.opacity(0.10), in: RoundedRectangle(cornerRadius: Metrics.corner))
    }

    private var sentence: String {
        guard let source else {
            return "The worktree was removed when this was archived. Looking for the branch it was on."
        }
        var text = "The worktree was removed when this was archived. "
            + source.explanation(branch: workspace.branch)
        if let plan = carryOn?.plan, let repo = model.repo {
            text += " " + ArchivedCarryOn.standing(
                project: repo.name, baseBranch: plan.baseBranch
            )
        }
        return text
    }

    private var symbol: String {
        guard let source else { return "clock" }
        if source.canRebuild { return "arrow.uturn.backward.circle" }
        return carryOn?.isOffered == true ? "arrow.forward.circle" : "text.book.closed"
    }

    private var tone: Color {
        guard let source else { return Palette.textTertiary }
        if source.canRebuild { return Palette.accent(beside: [.warning]) }
        return carryOn?.isOffered == true ? Palette.accent(beside: [.warning]) : Palette.warning
    }

    private var sessions: some View {
        HStack(spacing: Metrics.spacingWide) {
            Picker("Session", selection: sessionBinding) {
                ForEach(model.sessions) { session in
                    Text(session.title).tag(session.id as SessionID?)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 320)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacingSmall)
    }

    private var sessionBinding: Binding<SessionID?> {
        Binding(
            get: { model.activeSessionID },
            set: { model.activeSessionID = $0 }
        )
    }

    private func locateBranch() async {
        isLocating = true
        source = await app.restoreSource(for: workspace)
        isLocating = false
    }

    private var carryOnKey: CarryOnKey {
        CarryOnKey(
            workspace: workspace.id,
            session: model.activeSessionID,
            canRebuild: source?.canRebuild
        )
    }

    private struct CarryOnKey: Equatable {
        var workspace: WorkspaceID
        var session: SessionID?
        var canRebuild: Bool?
    }

    private func decideCarryOn() async {
        guard source != nil else {
            carryOn = nil
            return
        }
        carryOn = await app.carryOnDecision(
            for: workspace, session: model.activeSession, source: source
        )
    }
}
