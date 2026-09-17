import SwiftUI
import Core

struct ReviewPaneView: View {
    @Bindable var model: WorkspaceModel
    var tab: CenterTab
    var siblings: [PaneContent] = []

    private var changed: ChangedFile? {
        model.changedFiles.first { $0.path == tab.path }
    }

    @State private var exists: Bool?

    private var isPresent: Bool { exists ?? true }

    private struct ExistsID: Hashable {
        var path: String
        var generation: Int
    }

    @State private var room = ComposerRoom()

    var body: some View {
        VStack(spacing: 0) {
            if !tab.isPinnedToPath {
                reviewToolbar
                Hairline()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if drawsComposer {
                ReviewPaneComposer(model: model, room: room)
            }
        }
        .onGeometryChange(for: CGFloat.self) { PaneMeasure.room($0.size.height) } action: {
            room.height = $0
        }
        .background {
            ViewedShortcutHost(hasFile: !tab.showsAllFiles && changed != nil) {
                guard let changed else { return }
                let model = model
                Task { await model.setViewed(!model.isViewed(changed), file: changed) }
            }
        }
        .task(id: ExistsID(path: tab.path, generation: model.changesGeneration)) {
            let path = tab.path
            let absolute = Self.absolutePath(path, worktree: model.workspace.path)
            exists = await Task.detached(priority: .userInitiated) {
                !path.isEmpty && FileManager.default.fileExists(atPath: absolute)
            }.value
        }
    }

    private var drawsComposer: Bool {
        ReviewComposer.isDrawn(destination: model.reviewDestination?.id, panes: siblings)
    }

    @ViewBuilder
    private var content: some View {
        if tab.showsAllFiles, !tab.isPinnedToPath {
            AllFilesReviewView(
                model: model, selectedPath: tab.path,
                navigationRevision: tab.reviewNavigationRevision
            )
                .id(model.workspace.id)
        } else if let changed {
            DiffView(model: model, file: changed)
                .id("\(model.workspace.id.rawValue):\(changed.path)")
        } else if tab.path.isEmpty {
            EmptyStateView(
                glyph: "doc.text",
                title: "No file open",
                message: model.changedFiles.isEmpty
                    ? "Nothing in this worktree differs from \(model.workspace.baseBranch) yet."
                    : "Pick a file in the inspector to read it here."
            )
        } else if isPresent, FileMediaView.isMedia(path: tab.path) {
            FileMediaView(
                worktree: Self.isAbsolute(tab.path) ? "/" : model.workspace.path,
                path: Self.isAbsolute(tab.path) ? String(tab.path.dropFirst()) : tab.path
            )
                .id(tab.path)
        } else if isPresent {
            FilePreview(
                model: model,
                path: tab.path,
                absolutePathOverride: Self.isAbsolute(tab.path) ? tab.path : nil,
                canEditInApp: !Self.isAbsolute(tab.path)
            )
                .id(tab.path)
        } else {
            EmptyStateView(
                glyph: "doc.questionmark",
                title: "\((tab.path as NSString).lastPathComponent) is gone",
                message: "It is no longer in this worktree. Pick another file in the inspector."
            )
        }
    }

    private var reviewToolbar: some View {
        HStack(spacing: InspectorLayout.gap) {
            Picker("Review files", selection: Binding(
                get: { tab.showsAllFiles },
                set: { FileReview.setShowsAllFiles($0, in: model) }
            )) {
                Text("All files").tag(true)
                Text("Selected file").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()

            Spacer(minLength: 0)

            if tab.showsAllFiles {
                AllFilesReviewControls(model: model)
            } else {
                Text(model.diffScope.badge)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, InspectorLayout.inset)
        .frame(height: InspectorLayout.barHeight)
    }

    private static func isAbsolute(_ path: String) -> Bool {
        (path as NSString).isAbsolutePath
    }

    private static func absolutePath(_ path: String, worktree: String) -> String {
        isAbsolute(path) ? path : (worktree as NSString).appendingPathComponent(path)
    }
}
