import SwiftUI
import AppKit
import Core

struct CanvasSurface: View {
    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void

    private static let dragThreshold = 3.0

    @State private var viewport = CanvasViewport()
    @State private var panStart: CanvasPoint?
    @State private var zoomStart: CanvasViewport?
    @State private var size = CGSize.zero
    @State private var tool: CanvasTool
    @State private var selection: [CanvasElementID]
    @State private var guides: [CanvasGuide]
    @State private var movingIDs: [CanvasElementID]?
    @State private var movePlan: CanvasMovePlan?
    @State private var resizePreview: CanvasRect?

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        initialTool: CanvasTool = .hand,
        initialSelection: [CanvasElementID] = [],
        initialGuides: [CanvasGuide] = []
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        _tool = State(initialValue: initialTool)
        _selection = State(initialValue: initialSelection)
        _guides = State(initialValue: initialGuides)
    }

    private var liveSelection: [CanvasElementID] {
        selection.filter { id in document.elements.contains { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            canvas
            if !liveSelection.isEmpty {
                CanvasContextBar(
                    count: liveSelection.count,
                    align: { apply(CanvasAlignment.align(liveSelection, to: $0, in: document)) },
                    distribute: { apply(CanvasAlignment.distribute(liveSelection, axis: $0, in: document)) }
                )
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
            }
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
        .onChange(of: tool) { _, next in
            if next != .select { selection = [] }
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
            CanvasSelectionOverlay(
                viewport: viewport,
                rects: overlayRects,
                guides: guides,
                showsHandles: showsHandles,
                onResize: resize
            )
        }
        .coordinateSpace(.named(CanvasSelectionOverlay.space))
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag)
        .gesture(pinch)
    }

    private var overlayRects: [CanvasRect] {
        if let movePlan { return Array(movePlan.previews.values) }
        if let resizePreview { return [resizePreview] }
        return liveSelection.compactMap { id in
            document.elements.first { $0.id == id }.map { CanvasHitTest.absoluteRect(of: $0, in: document) }
        }
    }

    private var showsHandles: Bool { tool == .select && liveSelection.count == 1 && movePlan == nil }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                switch tool {
                case .hand: panChanged(value)
                case .select: selectChanged(value)
                default: break
                }
            }
            .onEnded { value in
                panStart = nil
                selectEnded(value)
            }
    }

    private func panChanged(_ value: DragGesture.Value) {
        let start = panStart ?? viewport.offset
        panStart = start
        viewport.offset = CanvasPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
    }

    private func selectChanged(_ value: DragGesture.Value) {
        if movingIDs == nil { beginSelect(at: value.startLocation) }
        guard let ids = movingIDs, !ids.isEmpty, hypot(value.translation.width, value.translation.height) > Self.dragThreshold else { return }
        let delta = CanvasPoint(x: value.translation.width / viewport.zoom, y: value.translation.height / viewport.zoom)
        let plan = CanvasMove.plan(moving: ids, by: delta, in: document)
        movePlan = plan
        guides = plan.guides
    }

    private func beginSelect(at location: CGPoint) {
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        let hit = CanvasHitTest.element(at: point, in: document)
        let extend = NSEvent.modifierFlags.contains(.shift)
        guard let hit else {
            if !extend { selection = [] }
            movingIDs = []
            return
        }
        if extend {
            if let index = selection.firstIndex(of: hit) { selection.remove(at: index) } else { selection.append(hit) }
            movingIDs = []
            return
        }
        if !selection.contains(hit) { selection = [hit] }
        movingIDs = liveSelection
    }

    private func selectEnded(_ value: DragGesture.Value) {
        defer {
            movingIDs = nil
            movePlan = nil
            guides = []
        }
        guard let ids = movingIDs, !ids.isEmpty, let plan = movePlan else { return }
        apply(CanvasMove.operations(moving: ids, by: plan.delta, in: document))
    }

    private func resize(_ handle: CanvasResizeHandle, to screenPoint: CGPoint, ended: Bool) {
        guard let id = liveSelection.first else { return }
        let point = viewport.toCanvas(CanvasPoint(x: screenPoint.x, y: screenPoint.y))
        let keepAspect = NSEvent.modifierFlags.contains(.shift)
        guard let rect = CanvasMove.resized(id, handle: handle, to: point, keepingAspect: keepAspect, in: document) else { return }
        if ended {
            resizePreview = nil
            apply(CanvasMove.operations(placing: id, at: rect, in: document))
        } else {
            resizePreview = rect
        }
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
        CanvasRect.union(of: document.frames.map(\.rect))
    }
}
