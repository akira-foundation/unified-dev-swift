import SwiftUI
import Core

struct CanvasEditorView: View {
    let model: CanvasDocumentModel
    let revision: Int

    var body: some View {
        switch model.document {
        case .document(let document):
            CanvasSurface(document: document, worktree: model.worktree, documentPath: model.path)
                .task(id: revision) { model.reload() }
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

struct CanvasSurface: View {
    let document: CanvasDocument
    let worktree: String
    let documentPath: String

    @State private var viewport = CanvasViewport()
    @State private var panStart: CanvasPoint?
    @State private var zoomStart: CanvasViewport?
    @State private var size = CGSize.zero
    @State private var tool = CanvasTool.hand

    var body: some View {
        ZStack(alignment: .bottom) {
            canvas
            CanvasToolbar(
                tool: $tool,
                zoom: viewport.zoom,
                zoomIn: { zoom(by: 1.25) },
                zoomOut: { zoom(by: 0.8) },
                fit: { fit(in: size) }
            )
            .padding(.bottom, 16)
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
            let first = size == .zero
            size = newSize
            if first { fit(in: newSize) }
        }
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
            ForEach(document.frames) { frame in
                let origin = viewport.toScreen(frame.rect.origin)
                CanvasFrameView(
                    frame: frame,
                    elements: document.elements.filter { $0.frameID == frame.id },
                    worktree: worktree,
                    documentPath: documentPath
                )
                .scaleEffect(viewport.zoom, anchor: .topLeading)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
                .overlay(alignment: .topLeading) {
                    Text(frame.name).font(.caption).foregroundStyle(.secondary).offset(y: -20)
                }
                .frame(width: 0, height: 0, alignment: .topLeading)
                .offset(x: origin.x, y: origin.y)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(pan)
        .gesture(pinch)
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard tool == .hand else { return }
                let start = panStart ?? viewport.offset
                panStart = start
                viewport.offset = CanvasPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            }
            .onEnded { _ in panStart = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? viewport
                zoomStart = start
                var next = start
                next.zoom(by: value.magnification, around: CanvasPoint(x: value.startLocation.x, y: value.startLocation.y))
                viewport = next
            }
            .onEnded { _ in zoomStart = nil }
    }

    private func zoom(by factor: Double) {
        viewport.zoom(by: factor, around: CanvasPoint(x: size.width / 2, y: size.height / 2))
    }

    private func fit(in available: CGSize) {
        guard let bounds = bounds else { return }
        viewport = CanvasViewport.fitting(bounds, in: CanvasSize(width: available.width, height: available.height))
    }

    private var bounds: CanvasRect? {
        guard let first = document.frames.first else { return nil }
        return document.frames.dropFirst().reduce(first.rect) { union, frame in
            let minX = min(union.origin.x, frame.rect.origin.x)
            let minY = min(union.origin.y, frame.rect.origin.y)
            let maxX = max(union.origin.x + union.size.width, frame.rect.origin.x + frame.rect.size.width)
            let maxY = max(union.origin.y + union.size.height, frame.rect.origin.y + frame.rect.size.height)
            return CanvasRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
