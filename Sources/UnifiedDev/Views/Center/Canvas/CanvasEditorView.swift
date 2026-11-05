import SwiftUI
import Core

struct CanvasEditorView: View {
    let model: CanvasDocumentModel
    let revision: Int
    var initialViewport: CanvasViewport?
    var initialShowsCommentList = false

    var body: some View {
        VStack(spacing: 0) {
            if let warning = model.warning {
                CanvasDiskWarningStrip(warning: warning, perform: { model.perform($0) })
            }
            if let notice = model.exportNotice {
                CanvasNoticeStrip(notice: notice, dismiss: { model.dismissExportNotice() })
            }
            if let notice = model.strokeNotice {
                CanvasNoticeStrip(notice: notice, dismiss: { model.dismissStrokeNotice() })
            }
            if let notice = model.imageNotice {
                CanvasNoticeStrip(notice: notice, dismiss: { model.imageNotice = nil })
            }
            content
        }
        .task(id: revision) {
            await model.reconcile()
            model.onCommentsNeedSettling?()
        }
        .environment(\.canvasPendingCommits, model.pendingCommits)
    }

    @ViewBuilder
    private var content: some View {
        switch model.document {
        case .document(let document):
            CanvasSurface(
                document: document,
                worktree: model.worktree,
                documentPath: model.path,
                apply: { model.apply($0) },
                addStroke: { model.addStroke($0, reduced: $1) },
                strokeNoticeShown: model.strokeNotice != nil,
                update: { model.update($0) },
                editing: model.editing,
                startEditing: { model.startEditing($0, text: $1) },
                finishEditing: { model.finishEditing() },
                undoManager: model.undoManager,
                importImage: { url, frame in Task { await model.addImage(from: url, in: frame) } },
                comments: CanvasCommentControls(model: model),
                exportFrames: { model.exportFrames() },
                initialViewport: initialViewport,
                initialShowsCommentList: initialShowsCommentList
            )
        case .corrupt(let reason):
            ContentUnavailableView(
                "This canvas cannot be read",
                systemImage: "exclamationmark.triangle",
                description: Text(reason)
            )
        case .newerVersion(let version):
            ContentUnavailableView(
                "This canvas needs a newer Unified Dev",
                systemImage: "arrow.down.app",
                description: Text("It was saved as version \(version), and this app reads up to version \(CanvasDocument.currentVersion).")
            )
        }
    }
}
