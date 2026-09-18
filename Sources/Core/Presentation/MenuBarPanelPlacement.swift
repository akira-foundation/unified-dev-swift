import Foundation

public struct MenuBarPanelPlacement: Equatable, Sendable {
    public static let width: CGFloat = 360
    public static let gap: CGFloat = 6
    public static let margin: CGFloat = 8

    public var frame: CGRect
    public var scrolls: Bool

    public init(frame: CGRect, scrolls: Bool) {
        self.frame = frame
        self.scrolls = scrolls
    }

    public static func place(
        anchor: CGRect,
        visible: CGRect,
        contentHeight: CGFloat,
        width: CGFloat = width
    ) -> MenuBarPanelPlacement {
        let top = min(anchor.minY, visible.maxY) - gap
        let room = max(1, top - (visible.minY + margin))
        let height = min(max(contentHeight, 1), room)
        let lowest = visible.minX + margin
        let highest = max(lowest, visible.maxX - margin - width)
        let x = min(max(anchor.midX - width / 2, lowest), highest)
        return MenuBarPanelPlacement(
            frame: CGRect(x: x, y: top - height, width: width, height: height),
            scrolls: contentHeight > room
        )
    }
}
