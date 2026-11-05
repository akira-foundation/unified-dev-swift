import SwiftUI
import Core

struct CanvasStage: View {
    static let hitSlop = 6.0
    private static let frameLabelFont = Font.caption

    private static func frameLabelWidth(_ name: String) -> Double {
        let font = NSFont.preferredFont(forTextStyle: .caption1)
        return (name as NSString).size(withAttributes: [.font: font]).width
    }

    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void
    let addStroke: (CanvasElement, Bool) -> Bool
    let strokeNoticeShown: Bool
    let editing: CanvasTextEditing?
    let startEditing: (CanvasElementID, CanvasText) -> Void
    let finishEditing: () -> Void
    let comments: CanvasCommentControls
    let undoFocus: CanvasUndoFocus
    let shapeKind: CanvasShape.Kind
    @Binding var viewport: CanvasViewport
    @Binding var tool: CanvasTool
    @Binding var selection: CanvasSelection
    @Binding var composingAt: CanvasPoint?

    @State private var panStart: CanvasPoint?
    @State private var zoomStart: CanvasViewport?
    @State private var guides: [CanvasGuide]
    @State private var pressTarget: CanvasDragTarget?
    @State private var movePlan: CanvasMovePlan?
    @State private var frameMovePlan: CanvasFrameMovePlan?
    @State private var resizePreview: CanvasRect?
    @State private var shapeDraft: CanvasShapeDraft?
    @State private var pen = CanvasPenDraft()
    @State private var panningWithModifier: Bool?
    @State private var gestureTool: CanvasTool?
    @GestureState private var dragging = false
    @State private var gestureSerial = 0

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        addStroke: @escaping (CanvasElement, Bool) -> Bool,
        strokeNoticeShown: Bool,
        editing: CanvasTextEditing?,
        startEditing: @escaping (CanvasElementID, CanvasText) -> Void,
        finishEditing: @escaping () -> Void,
        comments: CanvasCommentControls,
        undoFocus: CanvasUndoFocus,
        shapeKind: CanvasShape.Kind,
        guides: [CanvasGuide],
        viewport: Binding<CanvasViewport>,
        tool: Binding<CanvasTool>,
        selection: Binding<CanvasSelection>,
        composingAt: Binding<CanvasPoint?>
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        self.addStroke = addStroke
        self.strokeNoticeShown = strokeNoticeShown
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

    private var liveSelection: CanvasSelection { selection.live(in: document) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
            ForEach(document.frames) { frame in
                let origin = viewport.toScreen(screenRect(of: frame).origin)
                CanvasFrameView(
                    frame: frame,
                    elements: document.elements(in: frame.id).filter { $0.id != editing?.elementID },
                    worktree: worktree,
                    documentPath: documentPath
                )
                .scaleEffect(viewport.zoom, anchor: .topLeading)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
                .overlay(alignment: .topLeading) {
                    Text(frame.name)
                        .font(Self.frameLabelFont)
                        .foregroundStyle(liveSelection.frame == frame.id ? Color.accentColor : .secondary)
                        .offset(y: -CanvasHitTest.frameLabelHeight)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selection = CanvasSelection(frame: frame.id) }
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
                onResize: resize,
                onResizeCancelled: { resizePreview = nil }
            )
            if let shapeDraft {
                CanvasShapePreview(draft: shapeDraft, document: document, viewport: viewport)
            }
            if !pen.isEmpty {
                CanvasPenPreview(points: pen.points, viewport: viewport)
            }
            CanvasCommentMarks(comments: comments, viewport: viewport, composingAt: $composingAt, placed: { tool = .select })
        }
        .coordinateSpace(.named(CanvasSelectionOverlay.space))
        .overlay(alignment: .top) {
            if let notice = CanvasStrokeNotice.whileDrawing(pen) {
                CanvasPenLimitNotice(notice: notice)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { doubleClick(at: $0.location) })
        .gesture(pinch)
        .onChange(of: tool) { clearDrafts() }
        .onChange(of: strokeNoticeShown) { _, shown in
            if !shown { pen.noticeDismissed() }
        }
        .onChange(of: dragging) { _, active in
            guard !active, gestureTool != nil else { return }
            Task { @MainActor [serial = gestureSerial] in
                guard gestureTool != nil, gestureSerial == serial else { return }
                clearGesture()
                clearTransient()
            }
        }
    }

    private var overlayBoxes: [CanvasSelectionBox] {
        if let frame = document.frames.first(where: { $0.id == liveSelection.frame }) {
            return [CanvasSelectionBox(rect: screenRect(of: frame), rotation: 0)]
        }
        return liveSelection.elements.compactMap { id in
            guard let element = document.elements.first(where: { $0.id == id }) else { return nil }
            let rect = movePlan?.previews[id] ?? resizePreview ?? CanvasHitTest.absoluteRect(of: element, in: document)
            return CanvasSelectionBox(rect: rect, rotation: element.style.rotation)
        }
    }

    private func screenRect(of frame: CanvasFrame) -> CanvasRect {
        liveSelection.frame == frame.id ? frameMovePlan?.rect ?? frame.rect : frame.rect
    }

    private var showsHandles: Bool { tool == .select && liveSelection.elements.count == 1 && movePlan == nil }

    private func resize(_ handle: CanvasResizeHandle, by translation: CGSize, ended: Bool) {
        guard let id = liveSelection.elements.first else { return }
        let keepAspect = NSEvent.modifierFlags.contains(.shift)
        let screen = CanvasPoint(x: translation.width, y: translation.height)
        guard ended else {
            let delta = viewport.canvasDelta(forScreen: screen)
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
        selection = CanvasSelection(elements: [element.id])
        tool = .select
    }

    private func penChanged(_ value: DragGesture.Value) {
        pen.append(canvasPoint(value.location), tolerance: viewport.canvasLength(forScreen: CanvasPen.screenTolerance))
    }

    private func penEnded() {
        let reach = viewport.canvasLength(forScreen: CanvasPen.screenTolerance)
        guard let element = pen.element(width: CanvasPen.width, colour: CanvasPen.colour, tolerance: reach, in: document) else {
            pen = CanvasPenDraft()
            return
        }
        if addStroke(element, pen.wasCoarsened) {
            pen.refused()
        } else {
            pen = CanvasPenDraft()
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                let began = gestureTool ?? tool
                if gestureTool == nil { gestureSerial += 1 }
                gestureTool = began
                guard began == tool else { return }
                if editing == nil { undoFocus.take() }
                if panningWithModifier == nil {
                    panningWithModifier = began.pansWithOption && NSEvent.modifierFlags.contains(.option)
                }
                if panningWithModifier == true {
                    panChanged(value)
                    return
                }
                switch began {
                case .hand: panChanged(value)
                case .select: selectChanged(value)
                case .shape: shapeChanged(value)
                case .pen: penChanged(value)
                default: break
                }
            }
            .onEnded { value in
                let began = gestureTool ?? tool
                let panned = panningWithModifier == true
                clearGesture()
                guard !panned, began == tool else { return clearTransient() }
                let clicked = hypot(value.translation.width, value.translation.height) <= CanvasMove.dragThreshold
                if began == .text, clicked { placeText(at: value.startLocation) }
                if began == .note, clicked { placeNote(at: value.startLocation) }
                if began == .comment, clicked {
                    composingAt = viewport.toCanvas(CanvasPoint(x: value.startLocation.x, y: value.startLocation.y))
                }
                if began == .shape { shapeEnded(value, clicked: clicked) }
                if began == .pen { penEnded() }
                selectEnded(value)
            }
    }

    private func clearDrafts() {
        (shapeDraft, pen) = (nil, CanvasPenDraft())
    }

    private func clearTransient() {
        clearDrafts()
        pressTarget = nil
        movePlan = nil
        frameMovePlan = nil
        guides = []
    }

    private func clearGesture() {
        (panStart, gestureTool, panningWithModifier) = (nil, nil, nil)
    }

    private func panChanged(_ value: DragGesture.Value) {
        let start = panStart ?? viewport.offset
        panStart = start
        viewport.offset = CanvasPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
    }

    private func selectChanged(_ value: DragGesture.Value) {
        if pressTarget == nil { beginSelect(at: value.startLocation) }
        guard hypot(value.translation.width, value.translation.height) > CanvasMove.dragThreshold else { return }
        let delta = viewport.canvasDelta(forScreen: CanvasPoint(x: value.translation.width, y: value.translation.height))
        switch pressTarget {
        case .elements(let ids) where !ids.isEmpty:
            let plan = CanvasMove.plan(moving: ids, by: delta, in: document)
            movePlan = plan
            guides = plan.guides
        case .frame(let id):
            frameMovePlan = CanvasMove.plan(movingFrame: id, by: delta, in: document)
            guides = frameMovePlan?.guides ?? []
        default:
            break
        }
    }

    private func beginSelect(at location: CGPoint) {
        let screen = CanvasPoint(x: location.x, y: location.y)
        let point = viewport.toCanvas(screen)
        let label = CanvasHitTest.frameLabel(at: screen, in: document, viewport: viewport) { Self.frameLabelWidth($0.name) }
        let hit = label == nil
            ? CanvasHitTest.element(at: point, in: document, tolerance: viewport.canvasLength(forScreen: Self.hitSlop))
            : nil
        if hit != editing?.elementID { finishEditing() }
        let press = selection.pressed(
            label: label, element: hit, at: point, extending: NSEvent.modifierFlags.contains(.shift), in: document
        )
        selection = press.selection
        pressTarget = press.dragging
    }

    private func selectEnded(_ value: DragGesture.Value) {
        defer {
            pressTarget = nil
            movePlan = nil
            frameMovePlan = nil
            guides = []
        }
        if case .frame(let id)? = pressTarget, let plan = frameMovePlan {
            apply(CanvasMove.operations(movingFrame: id, to: plan.rect, in: document))
        }
        guard case .elements(let ids)? = pressTarget, !ids.isEmpty, let plan = movePlan else { return }
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
