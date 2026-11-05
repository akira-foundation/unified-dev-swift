import SwiftUI
import Core

extension CanvasSurface {
    func canvasPoint(_ location: CGPoint) -> CanvasPoint {
        viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
    }

    func shapeChanged(_ value: DragGesture.Value) {
        shapeDraft = CanvasShapeDraft(kind: shapeKind, start: canvasPoint(value.startLocation), end: canvasPoint(value.location))
    }

    func shapeEnded(_ value: DragGesture.Value, clicked: Bool) {
        shapeDraft = nil
        let start = canvasPoint(value.startLocation)
        let element = CanvasEditing.newShape(shapeKind, from: start, to: clicked ? start : canvasPoint(value.location), in: document)
        apply([.addElement(element)])
        selection = [element.id]
        tool = .select
    }

    func penChanged(_ value: DragGesture.Value) {
        guard penPoints.count < CanvasStrokeBuilder.maximumPoints else { return }
        penPoints.append(canvasPoint(value.location))
    }

    func penEnded() {
        defer { penPoints = [] }
        guard let element = CanvasStrokeBuilder.element(
            drawing: penPoints, width: CanvasPen.width, colour: CanvasPen.colour,
            tolerance: CanvasPen.screenTolerance / viewport.zoom, in: document
        ) else { return }
        apply([.addElement(element)])
    }

    func placeNote(at location: CGPoint) {
        let element = CanvasEditing.newNote(at: canvasPoint(location), in: document)
        guard let text = element.text else { return }
        apply([.addElement(element)])
        tool = .select
        beginTextEditing(element, text: text)
    }

    var drag: some Gesture {
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

    func panChanged(_ value: DragGesture.Value) {
        let start = panStart ?? viewport.offset
        panStart = start
        viewport.offset = CanvasPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
    }

    func selectChanged(_ value: DragGesture.Value) {
        if movingIDs == nil { beginSelect(at: value.startLocation) }
        guard let ids = movingIDs, !ids.isEmpty, hypot(value.translation.width, value.translation.height) > CanvasMove.dragThreshold else { return }
        let delta = CanvasPoint(x: value.translation.width / viewport.zoom, y: value.translation.height / viewport.zoom)
        let plan = CanvasMove.plan(moving: ids, by: delta, in: document)
        movePlan = plan
        guides = plan.guides
    }

    func beginSelect(at location: CGPoint) {
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

    func selectEnded(_ value: DragGesture.Value) {
        defer {
            movingIDs = nil
            movePlan = nil
            guides = []
        }
        guard let ids = movingIDs, !ids.isEmpty, let plan = movePlan else { return }
        apply(CanvasMove.operations(moving: ids, by: plan.delta, in: document))
    }
}
