import Foundation

public enum CanvasFramePreset: CaseIterable, Sendable {
    case square, portrait, free

    public static let gap = 80.0
    public static let freeDefaultSize = CanvasSize(width: 1280, height: 720)

    public var size: CanvasSize? {
        switch self {
        case .square: CanvasSize(width: 1080, height: 1080)
        case .portrait: CanvasSize(width: 1080, height: 1350)
        case .free: nil
        }
    }

    public var title: String {
        switch self {
        case .square: "Square 1080 by 1080"
        case .portrait: "Portrait 1080 by 1350"
        case .free: "Free size"
        }
    }

    public func newFrame(after frames: [CanvasFrame]) -> CanvasFrame {
        let last = frames.max { $0.rect.origin.x + $0.rect.size.width < $1.rect.origin.x + $1.rect.size.width }
        let origin = last.map {
            CanvasPoint(x: $0.rect.origin.x + $0.rect.size.width + Self.gap, y: $0.rect.origin.y)
        } ?? CanvasPoint(x: 0, y: 0)
        return CanvasFrame(
            name: Self.freeName(among: frames),
            rect: CanvasRect(origin: origin, size: size ?? Self.freeDefaultSize)
        )
    }

    private static func freeName(among frames: [CanvasFrame]) -> String {
        let taken = Set(frames.map(\.name))
        let number = (1...).first { !taken.contains("Slide \($0)") } ?? frames.count + 1
        return "Slide \(number)"
    }
}
