import SwiftUI
import Core

struct HomeListRow: View {
    var row: HomeRow
    var isRunning: Bool
    var isAwaitingPermission = false
    var now: Date
    var isRenaming: Bool
    var onCommitRename: (String) -> Void
    var onCancelRename: () -> Void

    @State private var draft = ""
    @State private var hasEnded = false
    @FocusState private var fieldFocused: Bool

    private var workspace: Workspace { row.workspace }

    private static let ageWidth: CGFloat = 34

    private static let diffWidth: CGFloat = 84

    var body: some View {
        HStack(spacing: Metrics.spacingWide) {
            RepoIcon(repo: row.repo)

            VStack(alignment: .leading, spacing: Metrics.spacingHair) {
                name
                origin
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .foregroundStyle(Palette.textPrimary)
        .grayscale(row.isArchived ? 1 : 0)
        .opacity(row.isArchived ? 0.6 : 1)
        .frame(minHeight: HomeMetrics.rowHeight)
        .contentShape(Rectangle())
        .focusedValue(\.isTypingProse, fieldFocused)
        .accessibilityElement(children: isRenaming ? .contain : .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityInputLabels([workspace.name])
        .accessibilityAddTraits(isRenaming ? [] : .isButton)
        .help(help)
    }

    @ViewBuilder
    private var name: some View {
        HStack(spacing: Metrics.spacing) {
            if isRenaming {
                TextField("Workspace name", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { end(.submitted) }
                    .onExitCommand { end(.escaped) }
                    .onChange(of: fieldFocused) { had, has in
                        guard had, !has else { return }
                        end(.focusLost)
                    }
                    .task {
                        draft = workspace.name
                        hasEnded = false
                        try? await Task.sleep(for: .milliseconds(30))
                        fieldFocused = true
                    }
            } else {
                WorkspaceNameText(workspace, isUnread: isUnread)
                    .lineLimit(1)
                    .truncationMode(.tail)

                WorkspaceColourDot(hex: workspace.colour)

                if workspace.pinned {
                    Image(systemName: "pin.fill")
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var origin: some View {
        HStack(spacing: Metrics.spacingSmall) {
            if let repo = row.repo {
                Text(repo.name)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)

                Text(verbatim: "/")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary.opacity(0.5))
            }

            Text(workspace.branch)
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var trailing: some View {
        HStack(spacing: Metrics.spacingWide) {
            if row.isArchived {
                Image(systemName: "archivebox")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: Metrics.glyph, height: Metrics.glyph)
                    .accessibilityHidden(true)
            } else {
                WorkspaceStatusGlyph(status: status, isOnSelection: false)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if let bytes = row.bytes {
                    Text(ArchiveDeletion.bytes(bytes))
                        .font(Typo.captionEmphasis)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                } else if workspace.hasDiff {
                    DiffStatLabel(
                        additions: workspace.additions,
                        deletions: workspace.deletions,
                        compact: true
                    )
                }
            }
            .frame(width: Self.diffWidth)

            Text(HomeAge.short(for: workspace.lastActivityAt, now: now))
                .font(Typo.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Self.ageWidth, alignment: .trailing)
        }
    }

    private var pullRequest: PullRequest? {
        WorkspacePullRequests.shared.pullRequest(for: workspace.id)
    }

    private var isUnread: Bool {
        WorkspaceUnreadMark.isUnread(workspace)
    }

    private var status: WorkspaceStatus {
        WorkspaceStatus.resolve(
            workspace: workspace,
            isRunning: isRunning,
            pullRequest: pullRequest,
            isAwaitingPermission: isAwaitingPermission
        )
    }

    private var statusDescription: String {
        row.isArchived ? "Archived" : status.summary(pullRequest: pullRequest)
    }

    private var help: String {
        var text = statusDescription
        if let repo = row.repo { text += " in \(repo.name)" }
        if let footprint = row.footprint { text += " \u{00B7} \(footprint.contents)" }
        return text
    }

    private var accessibilityLabel: String {
        var parts = [workspace.name]
        if let repo = row.repo { parts.append("in \(repo.name)") }
        if let match = row.match { parts.append("matched \(match)") }
        parts.append(statusDescription)
        if let colour = workspace.colourDescription { parts.append("colour \(colour)") }
        if workspace.pinned { parts.append("pinned") }
        if let bytes = row.bytes {
            parts.append("holding \(ArchiveDeletion.bytes(bytes))")
        } else if workspace.hasDiff {
            parts.append("\(workspace.additions) added, \(workspace.deletions) removed")
        }
        parts.append(
            workspace.lastActivityAt.formatted(
                .relative(presentation: .numeric, unitsStyle: .wide)
            )
        )
        return parts.joined(separator: ", ")
    }

    private func end(_ ending: InPlaceRename.Ending) {
        guard !hasEnded else { return }
        hasEnded = true
        guard case .commit(let name) = InPlaceRename.outcome(
            ending, draft: draft, current: workspace.name
        ) else { return onCancelRename() }
        onCommitRename(name)
    }
}

struct HomeRowBackground: View {
    var isSelected: Bool
    var isHovered: Bool

    private static let inset: CGFloat = Metrics.spacing

    var body: some View {
        Color.clear
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .fill(fill)
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 1)
            }
    }

    private var fill: Color {
        if isSelected { return Palette.selected }
        return isHovered ? Palette.hover : .clear
    }
}
