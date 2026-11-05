import SwiftUI
import Core

struct CanvasStage: View {
    static let hitSlop = 6.0

    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void
    let editing: CanvasTextEditing?
    let startEditing: (CanvasElementID, CanvasText) -> Void
    let finishEditing: () -> Void
    let comments: CanvasCommentControls
    let undoFocus: CanvasUndoFocus
    let shapeKind: CanvasShape.Kind
    @Binding var viewport: CanvasViewport
    @Binding var tool: CanvasTool
    @Binding var selection: [CanvasElementID]
    @Binding var composingAt: CanvasPoint?

    @State private var panStart: CanvasPoint?
    @State private var zoomStart: CanvasViewport?
    @State private var guides: [CanvasGuide]
    @State private var movingIDs: [CanvasElementID]?
    @State private var movePlan: CanvasMovePlan?
    @State private var resizePreview: CanvasRect?
    @State private var shapeDraft: CanvasShapeDraft?
    @State private var penPoints: [CanvasPoint] = []
    @State private var panningWithModifier: Bool?

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        editing: CanvasTextEditing?,
        startEditing: @escaping (CanvasElementID, CanvasText) -> Void,
        finishEditing: @escaping () -> Void,
        comments: CanvasCommentControls,
        undoFocus: CanvasUndoFocus,
        shapeKind: CanvasShape.Kind,
        guides: [CanvasGuide],
        viewport: Binding<CanvasViewport>,
        tool: Binding<CanvasTool>,
        selection: Binding<[CanvasElementID]>,
        composingAt: Binding<CanvasPoint?>
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        self.editing = editing
        self.startEditing = startEditing
        self.finishEditing = finishEditing
        self.comments = comments
        self.undoFocus = undoFocus
        self.shapeKind = shapeKind
        _guides = State(initialValue: guides)
        _viewport = viewport
        _tool = tool
        _selection = selection
        _composingAt = composingAt
    }

    private var liveSelection: [CanvasElementID] {
        selection.filter { id in document.elements.contains { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
            ForEach(document.frames) { frame in
                let origin = viewport.toScreen(frame.rect.origin)
                CanvasFrameView(
                    frame: frame,
                    elements: document.elements.filter { $0.frameID == frame.id && $0.id != editing?.elementID },
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
            ForEach(document.elements.filter { $0.frameID == nil && $0.id != editing?.elementID }) { element in
                let origin = viewport.toScreen(element.rect.origin)
                CanvasElementView(element: element, worktree: worktree, documentPath: documentPath)
                    .scaleEffect(viewport.zoom, anchor: .topLeading)
                    .frame(width: 0, height: 0, alignment: .topLeading)
                    .offset(x: origin.x, y: origin.y)
            }
            CanvasSelectionOverlay(
                viewport: viewport,
                boxes: overlayBoxes,
                guides: guides,
                showsHandles: showsHandles,
                onResize: resize
            )
            if let shapeDraft {
                CanvasShapePreview(draft: shapeDraft, document: document, viewport: viewport)
            }
            if !penPoints.isEmpty {
                CanvasPenPreview(points: penPoints, viewport: viewport)
            }
            CanvasCommentMarks(comments: comments, viewport: viewport, composingAt: $composingAt, placed: { tool = .select })
        }
        .coordinateSpace(.named(CanvasSelectionOverlay.space))
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { doubleClick(at: $0.location) })
        .gesture(pinch)
        .onChange(of: tool) {
            shapeDraft = nil
            penPoints = []
        }
    }

    private var overlayBoxes: [CanvasSelectionBox] {
        liveSelection.compactMap { id in
            guard let element = document.elements.first(where: { $0.id == id }) else { return nil }
            let rect = movePlan?.previews[id] ?? resizePreview ?? CanvasHitTest.absoluteRect(of: element, in: document)
            return CanvasSelectionBox(rect: rect, rotation: element.style.rotation)
        }
    }

    private var showsHandles: Bool { tool == .select && liveSelection.count == 1 && movePlan == nil }

    private func resize(_ handle: CanvasResizeHandle, by translation: CGSize, ended: Bool) {
        guard let id = liveSelection.first else { return }
        let keepAspect = NSEvent.modifierFlags.contains(.shift)
        let screen = CanvasPoint(x: translation.width, y: translation.height)
        guard ended else {
            let delta = CanvasPoint(x: screen.x / viewport.zoom, y: screen.y / viewport.zoom)
            resizePreview = CanvasMove.resized(id, handle: handle, translatedBy: delta, keepingAspect: keepAspect, in: document)
            return
        }
        resizePreview = nil
        apply(CanvasMove.operations(
            resizing: id, handle: handle, screenTranslation: screen, zoom: viewport.zoom, keepingAspect: keepAspect, in: document
        ))
    }

    func canvasPoint(_ location: CGPoint) -> CanvasPoint {
        viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
    }

    private func shapeChanged(_ value: DragGesture.Value) {
        shapeDraft = CanvasShapeDraft(kind: shapeKind, start: canvasPoint(value.startLocation), end: canvasPoint(value.location))
    }

    private func shapeEnded(_ value: DragGesture.Value, clicked: Bool) {
        shapeDraft = nil
        let start = canvasPoint(value.startLocation)
        let element = CanvasEditing.newShape(shapeKind, from: start, to: clicked ? start : canvasPoint(value.location), in: document)
        apply([.addElement(element)])
        selection = [element.id]
        tool = .select
    }

    private func penChanged(_ value: DragGesture.Value) {
        guard penPoints.count < CanvasStrokeBuilder.maximumPoints else { return }
        penPoints.append(canvasPoint(value.location))
    }

    private func penEnded() {
        defer { penPoints = [] }
        guard let element = CanvasStrokeBuilder.element(
            drawing: penPoints, width: CanvasPen.width, colour: CanvasPen.colour,
            tolerance: CanvasPen.screenTolerance / viewport.zoom, in: document
        ) else { return }
        apply([.addElement(element)])
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if editing == nil { undoFocus.take() }
                if panningWithModifier == nil {
                    panningWithModifier = tool.pansWithOption && NSEvent.modifierFlags.contains(.option)
                }
                if panningWithModifier == true {
                    panChanged(value)
                    return
                }
                switch tool {
                case .hand: panChanged(value)
                case .select: selectChanged(value)
                case .shape: shapeChanged(value)
                case .pen: penChanged(value)
                default: break
                }
            }
            .onEnded { value in
                panStart = nil
                let panned = panningWithModifier == true
                panningWithModifier = nil
                guard !panned else { return }
                let clicked = hypot(value.translation.width, value.translation.height) <= CanvasMove.dragThreshold
                if tool == .text, clicked { placeText(at: value.startLocation) }
                if tool == .note, clicked { placeNote(at: value.startLocation) }
                if tool == .comment, clicked {
                    composingAt = viewport.toCanvas(CanvasPoint(x: value.startLocation.x, y: value.startLocation.y))
                }
                if tool == .shape { shapeEnded(value, clicked: clicked) }
                if tool == .pen { penEnded() }
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
        guard let ids = movingIDs, !ids.isEmpty, hypot(value.translation.width, value.translation.height) > CanvasMove.dragThreshold else { return }
        let delta = CanvasPoint(x: value.translation.width / viewport.zoom, y: value.translation.height / viewport.zoom)
        let plan = CanvasMove.plan(moving: ids, by: delta, in: document)
        movePlan = plan
        guides = plan.guides
    }

    private func beginSelect(at location: CGPoint) {
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        let hit = CanvasHitTest.element(at: point, in: document, tolerance: Self.hitSlop / viewport.zoom)
        if hit != editing?.elementID { finishEditing() }
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
}
