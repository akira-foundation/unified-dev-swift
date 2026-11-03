import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

struct CanvasSurface: View {
    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let apply: ([CanvasOperation]) -> Void
    let beginEditing: (CanvasElementID) -> Void
    let importImage: (URL, CanvasFrameID) -> Void

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
    @State private var editing: CanvasTextEditing?

    init(
        document: CanvasDocument,
        worktree: String,
        documentPath: String,
        apply: @escaping ([CanvasOperation]) -> Void,
        beginEditing: @escaping (CanvasElementID) -> Void = { _ in },
        importImage: @escaping (URL, CanvasFrameID) -> Void = { _, _ in },
        initialTool: CanvasTool = .hand,
        initialSelection: [CanvasElementID] = [],
        initialGuides: [CanvasGuide] = [],
        initialEditing: CanvasElementID? = nil
    ) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.apply = apply
        self.beginEditing = beginEditing
        self.importImage = importImage
        _tool = State(initialValue: initialTool)
        _selection = State(initialValue: initialSelection)
        _guides = State(initialValue: initialGuides)
        _editing = State(initialValue: initialEditing.flatMap { id in
            document.elements.first { $0.id == id }.flatMap { element in
                element.text.map { CanvasTextEditing(elementID: id, text: $0) }
            }
        })
    }

    private var liveSelection: [CanvasElementID] {
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
                    apply: apply
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
            CanvasToolbar(
                tool: $tool,
                zoom: viewport.zoom,
                zoomIn: { zoom(by: 1.25) },
                zoomOut: { zoom(by: 0.8) },
                fit: { fit(in: size) },
                addFrame: { apply([.addFrame($0.newFrame(after: document.frames))]) },
                addImage: chooseImage,
                canAddImage: !document.frames.isEmpty
            )
            .padding(.bottom, 16)
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
            let first = size == .zero
            size = newSize
            if first { fit(in: newSize) }
        }
        .onChange(of: tool) { _, next in
            if next == .hand || next == .text { finishEditing() }
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
            CanvasSelectionOverlay(
                viewport: viewport,
                boxes: overlayBoxes,
                guides: guides,
                showsHandles: showsHandles,
                onResize: resize
            )
        }
        .coordinateSpace(.named(CanvasSelectionOverlay.space))
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { doubleClick(at: $0.location) })
        .gesture(pinch)
    }

    private func startEditing(_ element: CanvasElement, text: CanvasText) {
        finishEditing()
        beginEditing(element.id)
        editing = CanvasTextEditing(elementID: element.id, text: text)
        selection = [element.id]
    }

    private func finishEditing() {
        guard let current = editing else { return }
        editing = nil
        guard let element = document.elements.first(where: { $0.id == current.elementID }) else { return }
        let padding = CanvasEditing.notePadding(of: element)
        let measured = CanvasTextMeasure.size(of: current.text, width: element.rect.size.width - padding, padding: padding)
        let operations = CanvasEditing.operations(
            finishing: current.elementID, original: current.original, edited: current.text,
            measuredHeight: measured.height, in: document
        )
        if !operations.isEmpty { apply(operations) }
    }

    private func doubleClick(at location: CGPoint) {
        guard tool == .select || tool == .text else { return }
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        guard let id = CanvasHitTest.element(at: point, in: document),
              let element = document.elements.first(where: { $0.id == id }),
              let text = element.text else { return }
        tool = .select
        startEditing(element, text: text)
    }

    private func placeText(at location: CGPoint) {
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        if let id = CanvasHitTest.element(at: point, in: document),
           let existing = document.elements.first(where: { $0.id == id }),
           let text = existing.text {
            tool = .select
            startEditing(existing, text: text)
            return
        }
        let element = CanvasEditing.newText(at: point, in: document)
        guard let text = element.text else { return }
        apply([.addElement(element)])
        tool = .select
        startEditing(element, text: text)
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
                if tool == .text, hypot(value.translation.width, value.translation.height) <= CanvasMove.dragThreshold {
                    placeText(at: value.startLocation)
                }
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
        let hit = CanvasHitTest.element(at: point, in: document)
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
