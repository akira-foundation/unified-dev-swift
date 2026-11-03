import Foundation

public enum CanvasHitTest {
    public static func element(at point: CanvasPoint, in document: CanvasDocument) -> CanvasElementID? {
        document.elements.last { contains($0, point: point, in: document) }?.id
    }

    public static func absoluteRect(of element: CanvasElement, in document: CanvasDocument) -> CanvasRect {
        guard let frameID = element.frameID, let frame = document.frames.first(where: { $0.id == frameID }) else {
            return element.rect
        }
        return CanvasRect(
            x: frame.rect.origin.x + element.rect.origin.x,
            y: frame.rect.origin.y + element.rect.origin.y,
            width: element.rect.size.width,
            height: element.rect.size.height
        )
    }

    private static func contains(_ element: CanvasElement, point: CanvasPoint, in document: CanvasDocument) -> Bool {
        let rect = absoluteRect(of: element, in: document)
        let centre = CanvasPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        let radians = -element.style.rotation * .pi / 180
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let x = centre.x + dx * cos(radians) - dy * sin(radians)
        let y = centre.y + dx * sin(radians) + dy * cos(radians)
        return x >= rect.origin.x && x <= rect.origin.x + rect.size.width
            && y >= rect.origin.y && y <= rect.origin.y + rect.size.height
    }
}
