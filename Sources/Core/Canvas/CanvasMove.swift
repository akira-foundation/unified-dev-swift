import Foundation

public struct CanvasMovePlan: Sendable, Equatable {
    public var delta: CanvasPoint
    public var guides: [CanvasGuide]
    public var previews: [CanvasElementID: CanvasRect]
}

public struct CanvasFrameMovePlan: Sendable, Equatable {
    public var rect: CanvasRect
    public var guides: [CanvasGuide]
}

public enum CanvasMove {
    public static func plan(moving ids: [CanvasElementID], by delta: CanvasPoint, in document: CanvasDocument) -> CanvasMovePlan {
        let moving = document.elements.filter { ids.contains($0.id) }
        let starts = Dictionary(uniqueKeysWithValues: moving.map { ($0.id, CanvasHitTest.absoluteRect(of: $0, in: document)) })
        guard let group = CanvasRect.union(of: Array(starts.values)) else {
            return CanvasMovePlan(delta: delta, guides: [], previews: [:])
        }
        let shifted = CanvasRect(x: group.origin.x + delta.x, y: group.origin.y + delta.y, width: group.size.width, height: group.size.height)
        let others = document.elements.filter { !ids.contains($0.id) && $0.frameID == moving.first?.frameID }
            .map { CanvasHitTest.absoluteRect(of: $0, in: document) }
        let frame = moving.first?.frameID.flatMap { id in document.frames.first { $0.id == id }?.rect }
        let snapped = CanvasSnapping.snap(shifted, against: others, frame: frame)
        let snappedDelta = CanvasPoint(x: snapped.rect.origin.x - group.origin.x, y: snapped.rect.origin.y - group.origin.y)
        let previews = starts.mapValues {
            CanvasRect(x: $0.origin.x + snappedDelta.x, y: $0.origin.y + snappedDelta.y, width: $0.size.width, height: $0.size.height)
        }
        return CanvasMovePlan(delta: snappedDelta, guides: snapped.guides, previews: previews)
    }

    public static func operations(moving ids: [CanvasElementID], by delta: CanvasPoint, in document: CanvasDocument) -> [CanvasOperation] {
        guard delta.x != 0 || delta.y != 0 else { return [] }
        return document.elements.filter { ids.contains($0.id) }.map { element in
            let start = CanvasHitTest.absoluteRect(of: element, in: document)
            let shifted = CanvasRect(x: start.origin.x + delta.x, y: start.origin.y + delta.y, width: start.size.width, height: start.size.height)
            let target = CanvasEditing.frame(overlapping: shifted, keeping: element.frameID, in: document)
            let origin = target?.rect.origin ?? CanvasPoint(x: 0, y: 0)
            let rect = CanvasRect(x: shifted.origin.x - origin.x, y: shifted.origin.y - origin.y, width: shifted.size.width, height: shifted.size.height)
            guard target?.id != element.frameID else {
                return .updateElement(element.id, expectedRevision: element.revision, CanvasElementPatch(rect: rect))
            }
            let patch = target.map { CanvasElementPatch(frameID: $0.id, rect: rect) } ?? CanvasElementPatch(clearFrame: true, rect: rect)
            return .updateElement(element.id, expectedRevision: element.revision, patch)
        }
    }
}

extension CanvasMove {
    public static let dragThreshold = 3.0

    public static func resized(
        _ id: CanvasElementID, handle: CanvasResizeHandle, translatedBy delta: CanvasPoint, keepingAspect: Bool, in document: CanvasDocument
    ) -> CanvasRect? {
        guard let element = document.elements.first(where: { $0.id == id }) else { return nil }
        let start = CanvasHitTest.absoluteRect(of: element, in: document)
        let rotation = element.style.rotation
        let grabbed = CanvasResize.handlePoint(handle, of: start, rotation: rotation)
        let target = CanvasPoint(x: grabbed.x + delta.x, y: grabbed.y + delta.y)
        return CanvasResize.resized(start, rotation: rotation, handle: handle, to: target, keepingAspect: keepingAspect)
    }

    public static func operations(
        resizing id: CanvasElementID, handle: CanvasResizeHandle, screenTranslation: CanvasPoint, zoom: Double,
        keepingAspect: Bool, in document: CanvasDocument
    ) -> [CanvasOperation] {
        guard zoom > 0, hypot(screenTranslation.x, screenTranslation.y) > dragThreshold else { return [] }
        let delta = CanvasPoint(x: screenTranslation.x / zoom, y: screenTranslation.y / zoom)
        guard let rect = resized(id, handle: handle, translatedBy: delta, keepingAspect: keepingAspect, in: document) else { return [] }
        return operations(placing: id, at: rect, in: document)
    }

    public static func operations(placing id: CanvasElementID, at absolute: CanvasRect, in document: CanvasDocument) -> [CanvasOperation] {
        guard let element = document.elements.first(where: { $0.id == id }) else { return [] }
        let current = CanvasHitTest.absoluteRect(of: element, in: document)
        guard current != absolute else { return [] }
        let local = CanvasRect(
            x: element.rect.origin.x + absolute.origin.x - current.origin.x,
            y: element.rect.origin.y + absolute.origin.y - current.origin.y,
            width: absolute.size.width,
            height: absolute.size.height
        )
        return [.updateElement(id, expectedRevision: element.revision, CanvasElementPatch(rect: local))]
    }
}

extension CanvasMove {
    public static func plan(movingFrame id: CanvasFrameID, by delta: CanvasPoint, in document: CanvasDocument) -> CanvasFrameMovePlan? {
        guard let frame = document.frames.first(where: { $0.id == id }) else { return nil }
        let shifted = CanvasRect(
            x: frame.rect.origin.x + delta.x, y: frame.rect.origin.y + delta.y, width: frame.rect.size.width, height: frame.rect.size.height
        )
        let others = document.frames.filter { $0.id != id }.map(\.rect)
        let snapped = CanvasSnapping.snap(shifted, against: others, frame: nil)
        return CanvasFrameMovePlan(rect: snapped.rect, guides: snapped.guides)
    }

    public static func operations(movingFrame id: CanvasFrameID, to rect: CanvasRect, in document: CanvasDocument) -> [CanvasOperation] {
        guard let frame = document.frames.first(where: { $0.id == id }), frame.rect != rect else { return [] }
        return [.updateFrame(id, expectedRevision: nil, CanvasFramePatch(rect: rect))]
    }
}
