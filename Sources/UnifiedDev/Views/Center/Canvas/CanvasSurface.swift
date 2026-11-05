import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

struct CanvasSurface: View {
    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void
    let addStroke: (CanvasElement, Bool) -> Bool
    let strokeNoticeShown: Bool
    let update: ((CanvasDocument) -> [CanvasOperation]) -> Void
    let editing: CanvasTextEditing?
    let startEditing: (CanvasElementID, CanvasText) -> Void
    let finishEditing: () -> Void
    let undoManager: UndoManager?
    let importImage: (URL, CanvasFrameID) -> Void
    let comments: CanvasCommentControls
    let exportFrames: () -> Void
    private let startsAtViewport: Bool

    @State private var viewport: CanvasViewport
    @State private var size = CGSize.zero
    @State private var tool: CanvasTool
    @State private var selection: CanvasSelection
    private let guides: [CanvasGuide]
    @State private var undoFocus = CanvasUndoFocus()
    @State private var showsCommentList: Bool
    @State private var composingAt: CanvasPoint?
    @State private var shapeKind = CanvasShape.Kind.rectangle
    @State private var playing = false

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        addStroke: @escaping (CanvasElement, Bool) -> Bool = { _, _ in false },
        strokeNoticeShown: Bool = false,
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
        initialFrameSelection: CanvasFrameID? = nil,
        initialGuides: [CanvasGuide] = [],
        initialViewport: CanvasViewport? = nil,
        initialShowsCommentList: Bool = false
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        self.addStroke = addStroke
        self.strokeNoticeShown = strokeNoticeShown
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
        _selection = State(initialValue: CanvasSelection(elements: initialSelection, frame: initialFrameSelection))
        guides = initialGuides
    }

    private var liveElements: [CanvasElementID] { selection.live(in: document).elements }

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasStage(
                document: document,
                worktree: worktree,
                documentPath: documentPath,
                apply: apply,
                addStroke: addStroke,
                strokeNoticeShown: strokeNoticeShown,
                editing: editing,
                startEditing: startEditing,
                finishEditing: finishEditing,
                comments: comments,
                undoFocus: undoFocus,
                shapeKind: shapeKind,
                guides: guides,
                viewport: $viewport,
                tool: $tool,
                selection: $selection,
                composingAt: $composingAt
            )
            if let editing {
                CanvasTextEditorOverlay(editing: editing, document: document, viewport: viewport, finish: finishEditing)
            }
            if !liveElements.isEmpty {
                CanvasStylePanel(
                    elements: liveElements.compactMap { id in document.elements.first { $0.id == id } },
                    document: document,
                    editing: editing,
                    apply: apply,
                    update: update
                )
                .id(liveElements.map(\.rawValue))
                .frame(width: 300)
                .frame(maxHeight: 660)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            if !liveElements.isEmpty {
                CanvasContextBar(
                    count: liveElements.count,
                    align: { apply(CanvasAlignment.align(liveElements, to: $0, in: document)) },
                    distribute: { apply(CanvasAlignment.distribute(liveElements, axis: $0, in: document)) }
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
        .background {
            CanvasUndoResponder(
                manager: undoManager,
                focus: undoFocus,
                canDelete: selection.canDelete(in: document, isEditing: editing != nil, isPlaying: playing),
                delete: deleteSelection
            )
        }
        .onDisappear { finishEditing() }
        .onChange(of: editing == nil) { _, ended in
            if ended { undoFocus.returnAfterEditing() }
        }
        .onChange(of: tool) { _, next in
            if next != .select { finishEditing() }
            if next != .comment { composingAt = nil }
            if next != .select { selection = CanvasSelection() }
        }
    }

    private var leavesToSelectOnEscape: Bool { tool == .note || tool == .shape || tool == .pen }

    private var leaveToolButton: some View {
        Button("Select Tool") {
            tool = .select
        }
        .keyboardShortcut(.cancelAction)
        .disabled(!leavesToSelectOnEscape || playing)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func deleteSelection() {
        let (held, isEditing, isPlaying) = (selection, editing != nil, playing)
        update { held.deleteOperations(in: $0, isEditing: isEditing, isPlaying: isPlaying) }
    }

    private func startPlaying() {
        finishEditing()
        playing = true
    }

    private func chooseImage() {
        let centre = viewport.toCanvas(CanvasPoint(x: size.width / 2, y: size.height / 2))
        guard let frame = CanvasEditing.imageTarget(centre: centre, in: document),
              let url = Self.chooseImageFile() else { return }
        importImage(url, frame.id)
    }

    private func zoom(by factor: Double) {
        viewport.zoom(by: factor, around: CanvasPoint(x: size.width / 2, y: size.height / 2))
    }

    private func fit(in available: CGSize) {
        guard let bounds = CanvasRect.union(of: document.frames.map(\.rect)) else { return }
        viewport = CanvasViewport.fitting(bounds, in: CanvasSize(width: available.width, height: available.height))
    }
}
