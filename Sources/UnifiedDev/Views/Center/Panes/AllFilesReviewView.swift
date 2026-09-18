import SwiftUI
import Core

struct AllFilesReviewView: View {
    let model: WorkspaceModel
    let selectedPath: String
    let navigationRevision: Int
    @State private var pendingDestination: String?
    @State private var destinationSettled = false
    @State private var settleTask: Task<Void, Never>?
    @State private var layoutRevision = 0
    @State private var destinationPrepared = false
    @State private var collapsedPaths: Set<String> = []
    @State private var hasNavigated = false

    var body: some View {
        if model.reviewFiles.isEmpty {
            EmptyStateView(
                glyph: "doc.text",
                title: "No changes",
                message: model.diffScope.emptyMessage(base: model.workspace.baseBranch)
            )
        } else {
            GeometryReader { geometry in
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(model.reviewFiles) { file in
                                DiffView(
                                    model: model, file: file, embeddedWidth: geometry.size.width,
                                    defersDistantBlocks: true,
                                    isCollapsed: collapsedPaths.contains(file.path),
                                    onScrollFocus: {
                                        guard hasNavigated, pendingDestination == nil else { return }
                                        if model.selectedFilePath != file.path { model.selectedFilePath = file.path }
                                    },
                                    navigationTarget: pendingDestination == file.path,
                                    onNavigationLayout: {
                                        guard pendingDestination == file.path else { return }
                                        follow(file.path, using: reader)
                                    },
                                    onPrepared: {
                                        if pendingDestination == file.path { destinationPrepared = true }
                                        layoutRevision += 1
                                    },
                                    onToggleCollapsed: {
                                        pendingDestination = nil
                                        if !collapsedPaths.insert(file.path).inserted {
                                            collapsedPaths.remove(file.path)
                                        }
                                    }
                                )
                                .id(file.path)
                            }
                        }
                        .coordinateSpace(.named(ReviewDocument.space))
                        .background {
                            ReviewNavigationInput(armed: pendingDestination != nil) {
                                pendingDestination = nil
                            }
                        }
                    }
                    .defaultScrollAnchor(.topLeading)
                    .publishesReviewVisibleRect()
                    .onScrollPhaseChange { _, phase in
                        if phase == .tracking || phase == .interacting || phase == .decelerating {
                            pendingDestination = nil
                        }
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.y <= geometry.contentInsets.top
                    } action: { _, atTop in
                        if hasNavigated, pendingDestination == nil, atTop, let path = model.reviewFiles.first?.path,
                           model.selectedFilePath != path {
                            model.selectedFilePath = path
                        }
                    }
                    .onChange(of: navigationRevision, initial: true) { _, _ in
                        let requested = hasNavigated ? selectedPath : model.selectedFilePath ?? selectedPath
                        hasNavigated = true
                        let path = requested.isEmpty ? model.reviewFiles.first?.path : requested
                        guard let path, model.reviewFiles.contains(where: { $0.path == path }) else { return }
                        collapsedPaths.remove(path)
                        destinationPrepared = false
                        destinationSettled = false
                        pendingDestination = path
                        model.selectedFilePath = path
                        reader.scrollTo(path, anchor: .top)
                        restartSettleTimer()
                    }
                    .onScrollGeometryChange(for: CGSize.self) { geometry in
                        geometry.contentSize
                    } action: { _, _ in
                        if let path = pendingDestination { follow(path, using: reader) }
                    }
                    .onChange(of: layoutRevision) { _, _ in
                        if let path = pendingDestination { follow(path, using: reader) }
                    }
                    .onChange(of: geometry.size.width) { _, _ in
                        guard let path = pendingDestination else { return }
                        destinationSettled = false
                        follow(path, using: reader)
                    }
                    .onChange(of: model.reviewFiles.map(\.path)) { _, paths in
                        collapsedPaths.formIntersection(paths)
                        if let pendingDestination, !paths.contains(pendingDestination) { self.pendingDestination = nil }
                    }
                }
            }
        }
    }

    private func follow(_ path: String, using reader: ScrollViewProxy) {
        guard !destinationSettled else { return }
        scroll(to: path, using: reader)
        restartSettleTimer()
    }

    private func restartSettleTimer() {
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            destinationSettled = true
        }
    }

    private func scroll(to path: String, using reader: ScrollViewProxy) {
        let absolute = (model.workspace.path as NSString).appendingPathComponent(path)
        if destinationPrepared, let destination = SourceEditorState.file(absolute).diffRequest {
            reader.scrollTo("\(path):definition:\(destination.line)", anchor: .center)
        } else {
            reader.scrollTo(path, anchor: .top)
        }
    }
}
