public struct CanvasMovePlan: Sendable, Equatable {
    public var delta: CanvasPoint
    public var guides: [CanvasGuide]
    public var previews: [CanvasElementID: CanvasRect]
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
            let rect = CanvasRect(
                x: element.rect.origin.x + delta.x, y: element.rect.origin.y + delta.y,
                width: element.rect.size.width, height: element.rect.size.height
            )
            return .updateElement(element.id, expectedRevision: element.revision, CanvasElementPatch(rect: rect))
        }
    }
}

extension CanvasMove {
    public static func resized(
        _ id: CanvasElementID, handle: CanvasResizeHandle, to point: CanvasPoint, keepingAspect: Bool, in document: CanvasDocument
    ) -> CanvasRect? {
        guard let element = document.elements.first(where: { $0.id == id }) else { return nil }
        let start = CanvasHitTest.absoluteRect(of: element, in: document)
        return CanvasResize.resized(start, handle: handle, to: point, keepingAspect: keepingAspect)
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
