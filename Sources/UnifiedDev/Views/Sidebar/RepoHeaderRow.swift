import SwiftUI
import Core

struct RepoHeaderRow: View {
    var repo: Repo
    var hasUnreadWork: Bool
    var workspaceCount: Int
    var onCreateWorkspace: (Repo) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    @State private var isRenamingRepo = false
    @State private var repoDraft = ""
    @FocusState private var repoFieldFocused: Bool

    @State private var isConfirmingRemove = false
    @State private var removal: Confirmation?
    @State private var isHeaderHovered = false

    var body: some View {
        header
            .padding(.top, SidebarMetrics.headerLead)
            .opacity(repo.hidden ? SidebarMetrics.hiddenDim : 1)
    }

    private var header: some View {
        HStack(spacing: Metrics.spacing) {
            disclosure

            mark

            if isRenamingRepo {
                TextField("Project name", text: $repoDraft)
                    .textFieldStyle(.plain)
                    .font(Typo.title)
                    .focused($repoFieldFocused)
                    .onSubmit { endRepoRename(.submitted) }
                    .onExitCommand { endRepoRename(.escaped) }
                    .onChange(of: repoFieldFocused) { had, has in
                        guard had, !has else { return }
                        endRepoRename(.focusLost)
                    }
            } else {
                name
            }

            Spacer(minLength: Metrics.spacingSmall)

            Button {
                onCreateWorkspace(repo)
            } label: {
                Label("New workspace in \(repo.name)", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(Typo.label)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .foregroundStyle(isHeaderHovered ? Palette.textPrimary : Palette.textSecondary)
            .help("New workspace in \(repo.name)")
        }
        .contentShape(Rectangle())
        .onHoverChange { isHeaderHovered = $0 }
        .contextMenu {
            ProjectMenuItems(
                repo: repo,
                onCreateWorkspace: onCreateWorkspace,
                onRename: beginRepoRename,
                onRemove: askAboutRemoving
            )
        }
        .confirmationDialog(
            removal?.title ?? "",
            isPresented: $isConfirmingRemove,
            titleVisibility: .visible,
            presenting: removal
        ) { removal in
            Button(removal.confirmLabel, role: .destructive, action: removeRepo)
            Button(removal.cancelLabel, role: .cancel) {}
        } message: { removal in
            Text(removal.message)
        }
    }

    private static let unreadTitle = ScaledFont(.headline, weight: .heavy)

    private var countedName: String {
        let counted = workspaceCount == 1
            ? "\(repo.name), 1 workspace"
            : "\(repo.name), \(workspaceCount) workspaces"
        return repo.hidden ? counted + ", hidden" : counted
    }

    @ViewBuilder
    private var name: some View {
        let label = Text(repo.name)
            .font(hasUnreadWork ? Self.unreadTitle : Typo.title)
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(1)

        let counted = label.accessibilityLabel(Text(countedName))

        if hasUnreadWork {
            counted
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue("Has unread work")
        } else {
            counted.accessibilityAddTraits(.isHeader)
        }
    }

    private var mark: some View {
        ZStack {
            RepoIcon(repo: repo)
                .opacity(isHeaderHovered ? 0 : 1)

            settingsButton
                .foregroundStyle(isHeaderHovered ? Palette.textPrimary : Color.clear)
                .allowsHitTesting(isHeaderHovered)
        }
        .frame(width: Metrics.repoIcon, height: Metrics.repoIcon)
        .padding(.trailing, SidebarMetrics.markGap - Metrics.spacing)
        .animation(reduceMotion ? nil : Motion.hover, value: isHeaderHovered)
    }

    private var settingsButton: some View {
        Button {
            openWindow(id: RepoSettingsWindow.id, value: repo.id)
        } label: {
            Label("Settings for \(repo.name)", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .font(Typo.label)
                .frame(width: Metrics.repoIcon, height: Metrics.repoIcon)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        }
        .buttonStyle(.plain)
        .help("Settings for \(repo.name)")
    }

    private var disclosure: some View {
        Button {
            Task { await app.toggleCollapsed(repo) }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: SidebarMetrics.caretSize, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .rotationEffect(.degrees(repo.collapsed ? 0 : 90))
                .frame(width: SidebarMetrics.caretGutter, height: Metrics.repoIcon)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : Motion.pane, value: repo.collapsed)
        .accessibilityLabel(repo.collapsed ? "Show workspaces in \(repo.name)" : "Hide workspaces in \(repo.name)")
        .accessibilityValue(repo.collapsed ? "Collapsed" : "Expanded")
        .help(repo.collapsed ? "Show workspaces" : "Hide workspaces")
    }

    private func askAboutRemoving() {
        removal = app.projectRemoval(repo)
        isConfirmingRemove = true
    }

    private func removeRepo() {
        Task { await app.removeRepository(repo) }
    }

    private func beginRepoRename() {
        repoDraft = repo.name
        isRenamingRepo = true
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            repoFieldFocused = true
        }
    }

    private func endRepoRename(_ ending: InPlaceRename.Ending) {
        guard isRenamingRepo else { return }
        isRenamingRepo = false
        guard case .commit(let name) = InPlaceRename.outcome(
            ending, draft: repoDraft, current: repo.name
        ) else { return }
        Task { await app.rename(repo, to: name) }
    }
}
