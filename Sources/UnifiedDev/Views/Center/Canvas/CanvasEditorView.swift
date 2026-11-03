import SwiftUI
import Core

struct CanvasEditorView: View {
    let model: CanvasDocumentModel
    let revision: Int

    var body: some View {
        VStack(spacing: 0) {
            if let warning = model.warning {
                CanvasDiskWarningStrip(warning: warning, perform: { model.perform($0) })
            }
            content
        }
        .task(id: revision) { await model.reconcile() }
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
                update: { model.update($0) },
                editing: model.editing,
                startEditing: { model.startEditing($0, text: $1) },
                finishEditing: { model.finishEditing() },
                undoManager: model.undoManager,
                importImage: { url, frame in Task { await model.addImage(from: url, in: frame) } }
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
