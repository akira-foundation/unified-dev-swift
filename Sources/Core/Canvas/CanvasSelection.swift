import Foundation

public enum CanvasDragTarget: Sendable, Equatable {
    case nothing
    case elements([CanvasElementID])
    case frame(CanvasFrameID)
}

public struct CanvasPress: Sendable, Equatable {
    public var selection: CanvasSelection
    public var dragging: CanvasDragTarget
}

public struct CanvasSelection: Sendable, Equatable {
    public let elements: [CanvasElementID]
    public let frame: CanvasFrameID?

    public init(elements: [CanvasElementID] = [], frame: CanvasFrameID? = nil) {
        self.elements = frame == nil ? elements : []
        self.frame = frame
    }

    public var isEmpty: Bool { elements.isEmpty && frame == nil }

    public func live(in document: CanvasDocument) -> CanvasSelection {
        CanvasSelection(
            elements: elements.filter { id in document.elements.contains { $0.id == id } },
            frame: frame.flatMap { id in document.frames.contains { $0.id == id } ? id : nil }
        )
    }

    public func pressed(
        label: CanvasFrameID?, element: CanvasElementID?, at point: CanvasPoint, extending: Bool, in document: CanvasDocument
    ) -> CanvasPress {
        if let label {
            return CanvasPress(selection: CanvasSelection(frame: label), dragging: .frame(label))
        }
        if let element {
            return pressed(element, extending: extending, in: document)
        }
        if !extending, let frame, let rect = document.frames.first(where: { $0.id == frame })?.rect, Self.contains(rect, point) {
            return CanvasPress(selection: self, dragging: .frame(frame))
        }
        return CanvasPress(selection: extending ? self : CanvasSelection(), dragging: .nothing)
    }

    private func pressed(_ hit: CanvasElementID, extending: Bool, in document: CanvasDocument) -> CanvasPress {
        guard extending else {
            let next = elements.contains(hit) ? self : CanvasSelection(elements: [hit])
            return CanvasPress(selection: next, dragging: .elements(next.live(in: document).elements))
        }
        let toggled = elements.contains(hit) ? elements.filter { $0 != hit } : elements + [hit]
        return CanvasPress(selection: CanvasSelection(elements: toggled), dragging: .nothing)
    }

    private static func contains(_ rect: CanvasRect, _ point: CanvasPoint) -> Bool {
        point.x >= rect.origin.x && point.x <= rect.origin.x + rect.size.width
            && point.y >= rect.origin.y && point.y <= rect.origin.y + rect.size.height
    }
}
