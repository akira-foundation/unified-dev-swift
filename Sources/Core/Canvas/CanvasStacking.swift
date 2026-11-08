import Foundation

public enum CanvasStackingDirection: Sendable, CaseIterable {
    case toBack, backward, forward, toFront
}

public enum CanvasStacking {
    public static func operations(
        moving id: CanvasElementID, _ direction: CanvasStackingDirection, in document: CanvasDocument
    ) -> [CanvasOperation] {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else { return [] }
        let last = document.elements.count - 1
        let target = switch direction {
        case .toBack: 0
        case .backward: max(index - 1, 0)
        case .forward: min(index + 1, last)
        case .toFront: last
        }
        return target == index ? [] : [.reorder(id, toIndex: target)]
    }
}
