import CoreGraphics

public enum HoverCardPlacement {
    public enum Side: Sendable, Hashable {
        case trailing
        case below
    }

    public static let gap: CGFloat = 8

    public static let screenMargin: CGFloat = 8

    public static func frame(
        anchor: CGRect,
        size: CGSize,
        visible: CGRect,
        side: Side = .trailing
    ) -> CGRect {
        var origin = switch side {
        case .trailing:
            CGPoint(
                x: anchor.maxX + gap,
                y: anchor.maxY - size.height
            )
        case .below:
            CGPoint(
                x: anchor.maxX - size.width,
                y: anchor.minY - gap - size.height
            )
        }

        if side == .trailing, origin.x + size.width > visible.maxX - screenMargin {
            let flipped = anchor.minX - gap - size.width
            if flipped >= visible.minX + screenMargin { origin.x = flipped }
        }

        if side == .below, origin.y < visible.minY + screenMargin {
            let flipped = anchor.maxY + gap
            if flipped + size.height <= visible.maxY - screenMargin { origin.y = flipped }
        }

        origin.x = min(origin.x, visible.maxX - screenMargin - size.width)
        origin.x = max(origin.x, visible.minX + screenMargin)

        origin.y = max(origin.y, visible.minY + screenMargin)
        origin.y = min(origin.y, visible.maxY - screenMargin - size.height)

        return CGRect(origin: origin, size: size)
    }
}
