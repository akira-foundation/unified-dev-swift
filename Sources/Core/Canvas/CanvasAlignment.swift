public enum CanvasAlignEdge: CaseIterable, Sendable, Hashable {
    case left, centreX, right, top, middleY, bottom
}

public enum CanvasAlignment {
    public static func align(
        _ ids: [CanvasElementID], to edge: CanvasAlignEdge, in document: CanvasDocument
    ) -> [CanvasOperation] {
        let members = members(of: ids, in: document)
        guard let reference = reference(for: members, in: document) else { return [] }
        return members.compactMap { member in
            var rect = member.absolute
            switch edge {
            case .left: rect.origin.x = reference.origin.x
            case .centreX: rect.origin.x = reference.origin.x + (reference.size.width - rect.size.width) / 2
            case .right: rect.origin.x = reference.origin.x + reference.size.width - rect.size.width
            case .top: rect.origin.y = reference.origin.y
            case .middleY: rect.origin.y = reference.origin.y + (reference.size.height - rect.size.height) / 2
            case .bottom: rect.origin.y = reference.origin.y + reference.size.height - rect.size.height
            }
            return operation(moving: member, to: rect, in: document)
        }
    }

    public static func distribute(
        _ ids: [CanvasElementID], axis: CanvasAxis, in document: CanvasDocument
    ) -> [CanvasOperation] {
        let members = members(of: ids, in: document)
        guard members.count >= 3 else { return [] }
        let start: (CanvasRect) -> Double = { axis == .horizontal ? $0.origin.x : $0.origin.y }
        let length: (CanvasRect) -> Double = { axis == .horizontal ? $0.size.width : $0.size.height }
        let ordered = members.sorted { start($0.absolute) < start($1.absolute) }
        guard let first = ordered.first, let last = ordered.last else { return [] }
        let span = start(last.absolute) + length(last.absolute) - start(first.absolute)
        let gap = (span - ordered.reduce(0) { $0 + length($1.absolute) }) / Double(ordered.count - 1)
        var cursor = start(first.absolute) + length(first.absolute) + gap
        return ordered.dropFirst().dropLast().compactMap { member in
            var rect = member.absolute
            if axis == .horizontal { rect.origin.x = cursor } else { rect.origin.y = cursor }
            cursor += length(rect) + gap
            return operation(moving: member, to: rect, in: document)
        }
    }

    private struct Member {
        let element: CanvasElement
        let absolute: CanvasRect
    }

    private static func members(of ids: [CanvasElementID], in document: CanvasDocument) -> [Member] {
        var seen = Set<CanvasElementID>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted, let element = document.elements.first(where: { $0.id == id }) else { return nil }
            return Member(element: element, absolute: CanvasHitTest.absoluteRect(of: element, in: document))
        }
    }

    private static func reference(for members: [Member], in document: CanvasDocument) -> CanvasRect? {
        guard let only = members.first, members.count == 1 else {
            return CanvasRect.union(of: members.map(\.absolute))
        }
        guard let frameID = only.element.frameID else { return nil }
        return document.frames.first { $0.id == frameID }?.rect
    }

    private static func operation(moving member: Member, to absolute: CanvasRect, in document: CanvasDocument) -> CanvasOperation? {
        guard absolute != member.absolute else { return nil }
        let delta = CanvasPoint(x: absolute.origin.x - member.absolute.origin.x, y: absolute.origin.y - member.absolute.origin.y)
        let local = CanvasRect(
            x: member.element.rect.origin.x + delta.x,
            y: member.element.rect.origin.y + delta.y,
            width: member.element.rect.size.width,
            height: member.element.rect.size.height
        )
        return .updateElement(member.element.id, expectedRevision: member.element.revision, CanvasElementPatch(rect: local))
    }
}
