import CoreGraphics

public struct WindowCompositeLayout: Sendable, Equatable {
    public let bounds: CGRect
    public let size: CGSize
    public let parent: CGRect
    public let children: [CGRect]

    public init(bounds: CGRect, size: CGSize, parent: CGRect, children: [CGRect]) {
        self.bounds = bounds
        self.size = size
        self.parent = parent
        self.children = children
    }

    public func flipped(in screen: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX - screen.minX,
            y: screen.maxY - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
    }
}

public enum WindowComposite {
    public static func layout(
        parent: CGRect,
        children: [CGRect],
        scale: CGFloat,
        within screen: CGRect = .null
    ) -> WindowCompositeLayout {
        let factor = scale > 0 ? scale : 1
        let drawn = children.filter { $0.width > 0 && $0.height > 0 }
        let reach = drawn.reduce(parent) { $0.union($1) }
        let clipped = reach.intersection(screen)
        let union = screen.isNull || screen.isEmpty || clipped.isNull ? reach : clipped

        func placed(_ frame: CGRect) -> CGRect {
            CGRect(
                x: (frame.minX - union.minX) * factor,
                y: (union.maxY - frame.maxY) * factor,
                width: frame.width * factor,
                height: frame.height * factor
            )
        }

        return WindowCompositeLayout(
            bounds: union,
            size: CGSize(width: union.width * factor, height: union.height * factor),
            parent: placed(parent),
            children: drawn.map(placed)
        )
    }

    public static func staged(child: CGRect, number: Int, with parent: CGRect) -> Bool {
        number > 0 && child.width > 0 && child.height > 0 && child.intersects(parent)
    }
}
