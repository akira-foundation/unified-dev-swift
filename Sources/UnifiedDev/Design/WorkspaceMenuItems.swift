import SwiftUI
import Core

struct WorkspaceMenuItems: View {
    var workspace: Workspace
    var onArchive: (() -> Void)?
    var onRename: (WorkspaceID) -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        openInEditorItem
        openWorktreeInItem
        revealInFinderItem
        copyBranchItem
        setupItem
        Divider()
        WorkspacePinItem(workspace: workspace, app: app)
        WorkspaceUnreadItem(workspace: workspace, app: app)
        WorkspaceColourItem(workspace: workspace, app: app)
        renameItem
        Divider()
        Button("Archive", role: .destructive) {
            if let onArchive {
                onArchive()
            } else {
                Task { await app.archive(workspace) }
            }
        }
    }

    private var renameItem: some View {
        Button("Rename") { onRename(workspace.id) }
    }

    private var openInEditorItem: some View {
        Button("Open in Editor") { Reveal.inEditor(workspace.path, repo: workspace.repoID) }
    }

    private var openWorktreeInItem: some View {
        OpenInMenu(target: .folder(workspace.path), noun: "Worktree")
            .environment(\.openInRepoID, workspace.repoID)
    }

    private var revealInFinderItem: some View {
        Button("Reveal in Finder") { Reveal.inFinder(workspace.path) }
    }

    private var copyBranchItem: some View {
        Button("Copy Branch Name") { Clipboard.copy(workspace.branch) }
    }

    @ViewBuilder
    private var setupItem: some View {
        if let model = app.existingModel(for: workspace.id), let offer = model.setupRunOffer {
            Button(offer.title) { SetupRunAlert.shared.ask(model) }
                .disabled(!offer.isEnabled)
        }
    }
}

struct WorkspacePinItem: View {
    var workspace: Workspace
    var app: AppModel

    var body: some View {
        MenuCommand(.pin, alternate: workspace.pinned) {
            Task { await app.togglePinned(workspace) }
        }
    }
}

struct WorkspaceUnreadItem: View {
    var workspace: Workspace
    var app: AppModel

    var body: some View {
        if let mark = WorkspaceUnreadMark.action(for: workspace) {
            MenuCommand(.unreadMark, alternate: mark == .markRead) {
                Task { await app.setUnread(workspace, mark.unread) }
            }
        }
    }
}

struct WorkspaceColourItem: View {
    var workspace: Workspace
    var app: AppModel

    var body: some View {
        Picker(MenuBarCatalogue[.colour].title, selection: selection) {
            Text("None").tag("")
            ForEach(WorkspaceColour.all) { colour in
                Label {
                    Text(colour.name)
                } icon: {
                    if let swatch = WorkspaceColourImage.of(colour.hex) {
                        Image(nsImage: swatch).renderingMode(.original)
                    }
                }
                .tag(colour.hex)
            }
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { workspace.colour ?? "" },
            set: { hex in
                Task { await app.setColour(workspace, to: hex.isEmpty ? nil : hex) }
            }
        )
    }
}
