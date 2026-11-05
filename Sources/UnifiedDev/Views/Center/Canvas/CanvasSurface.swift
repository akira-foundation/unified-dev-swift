import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

struct CanvasSurface: View {
    static let hitSlop = 6.0

    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void
    let update: ((CanvasDocument) -> [CanvasOperation]) -> Void
    let editing: CanvasTextEditing?
    let startEditing: (CanvasElementID, CanvasText) -> Void
    let finishEditing: () -> Void
    let undoManager: UndoManager?
    let importImage: (URL, CanvasFrameID) -> Void
    let comments: CanvasCommentControls
    let exportFrames: () -> Void
    private let startsAtViewport: Bool

    @State var viewport: CanvasViewport
    @State var panStart: CanvasPoint?
    @State var zoomStart: CanvasViewport?
    @State var size = CGSize.zero
    @State var tool: CanvasTool
    @State var selection: [CanvasElementID]
    @State var guides: [CanvasGuide]
    @State var movingIDs: [CanvasElementID]?
    @State var movePlan: CanvasMovePlan?
    @State private var resizePreview: CanvasRect?
    @State var undoFocus = CanvasUndoFocus()
    @State private var showsCommentList: Bool
    @State var composingAt: CanvasPoint?
    @State var shapeKind = CanvasShape.Kind.rectangle
    @State var shapeDraft: CanvasShapeDraft?
    @State var penPoints: [CanvasPoint] = []
    @State var panningWithModifier: Bool?
    @State private var playing = false

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        update: @escaping ((CanvasDocument) -> [CanvasOperation]) -> Void = { _ in },
        editing: CanvasTextEditing? = nil,
        startEditing: @escaping (CanvasElementID, CanvasText) -> Void = { _, _ in },
        finishEditing: @escaping () -> Void = {},
        undoManager: UndoManager? = nil,
        importImage: @escaping (URL, CanvasFrameID) -> Void = { _, _ in },
        comments: CanvasCommentControls = .none,
        exportFrames: @escaping () -> Void = {},
        initialTool: CanvasTool = .hand,
        initialSelection: [CanvasElementID] = [],
        initialGuides: [CanvasGuide] = [],
        initialViewport: CanvasViewport? = nil,
        initialShowsCommentList: Bool = false
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        self.update = update
        self.editing = editing
        self.startEditing = startEditing
        self.finishEditing = finishEditing
        self.undoManager = undoManager
        self.importImage = importImage
        self.comments = comments
        self.exportFrames = exportFrames
        startsAtViewport = initialViewport != nil
        _viewport = State(initialValue: initialViewport ?? CanvasViewport())
        _showsCommentList = State(initialValue: initialShowsCommentList)
        _tool = State(initialValue: initialTool)
        _selection = State(initialValue: initialSelection)
        _guides = State(initialValue: initialGuides)
    }

    var liveSelection: [CanvasElementID] {
        selection.filter { id in document.elements.contains { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            canvas
            if let editing {
                CanvasTextEditorOverlay(editing: editing, document: document, viewport: viewport, finish: finishEditing)
            }
            if !liveSelection.isEmpty {
                CanvasStylePanel(
                    elements: liveSelection.compactMap { id in document.elements.first { $0.id == id } },
                    document: document,
                    editing: editing,
                    apply: apply,
                    update: update
                )
                .id(liveSelection.map(\.rawValue))
                .frame(width: 300)
                .frame(maxHeight: 660)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            if !liveSelection.isEmpty {
                CanvasContextBar(
                    count: liveSelection.count,
                    align: { apply(CanvasAlignment.align(liveSelection, to: $0, in: document)) },
                    distribute: { apply(CanvasAlignment.distribute(liveSelection, axis: $0, in: document)) }
                )
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            CanvasCommentTools(
                tool: $tool,
                comments: comments,
                showsList: $showsCommentList
            )
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            CanvasToolbar(
                tool: $tool,
                shapeKind: $shapeKind,
                zoom: viewport.zoom,
                zoomIn: { zoom(by: 1.25) },
                zoomOut: { zoom(by: 0.8) },
                fit: { fit(in: size) },
                addFrame: { apply([.addFrame($0.newFrame(after: document.frames))]) },
                addImage: chooseImage,
                canAddImage: !document.frames.isEmpty,
                exportFrames: exportFrames,
                canExport: !document.frames.isEmpty,
                play: startPlaying,
                canPlay: !document.frames.isEmpty
            )
            .padding(.bottom, 16)
            if playing {
                CanvasPlaybackView(
                    document: document, worktree: worktree, documentPath: documentPath, close: { playing = false }
                )
            }
        }
        .background { leaveToolButton }
        .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
            let first = size == .zero
            size = newSize
            if first, !startsAtViewport { fit(in: newSize) }
        }
        .background { CanvasUndoResponder(manager: undoManager, focus: undoFocus) }
        .onDisappear { finishEditing() }
        .onChange(of: editing == nil) { _, ended in
            if ended { undoFocus.returnAfterEditing() }
        }
        .onChange(of: tool) { _, next in
            if next == .hand || next == .text || next == .comment { finishEditing() }
            if next != .comment { composingAt = nil }
            if next != .select { selection = [] }
            shapeDraft = nil
            penPoints = []
        }
    }

    private var leavesToSelectOnEscape: Bool { tool == .note || tool == .shape || tool == .pen }

    private var leaveToolButton: some View {
        Button("Select Tool") {
            shapeDraft = nil
            penPoints = []
            tool = .select
        }
        .keyboardShortcut(.cancelAction)
        .disabled(!leavesToSelectOnEscape || playing)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func startPlaying() {
        finishEditing()
        playing = true
    }

    private var canvas: some View {
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
    }

    func beginTextEditing(_ element: CanvasElement, text: CanvasText) {
        startEditing(element.id, text)
        selection = [element.id]
    }

    private func doubleClick(at location: CGPoint) {
        guard tool == .select || tool == .text else { return }
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        guard let id = CanvasHitTest.element(at: point, in: document),
              let element = document.elements.first(where: { $0.id == id }),
              let text = element.text else { return }
        tool = .select
        beginTextEditing(element, text: text)
    }

    func placeText(at location: CGPoint) {
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        if let id = CanvasHitTest.element(at: point, in: document),
           let existing = document.elements.first(where: { $0.id == id }),
           let text = existing.text {
            tool = .select
            beginTextEditing(existing, text: text)
            return
        }
        let element = CanvasEditing.newText(at: point, in: document)
        guard let text = element.text else { return }
        apply([.addElement(element)])
        tool = .select
        beginTextEditing(element, text: text)
    }

    private func chooseImage() {
        let centre = viewport.toCanvas(CanvasPoint(x: size.width / 2, y: size.height / 2))
        guard let frame = CanvasEditing.imageTarget(centre: centre, in: document),
              let url = Self.chooseImageFile() else { return }
        importImage(url, frame.id)
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
}
