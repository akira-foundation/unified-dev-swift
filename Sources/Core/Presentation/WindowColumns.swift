import CoreGraphics

public struct WindowColumns: Equatable, Sendable {
    public enum Reach: Equatable, Sendable {
        case all
        case withoutSidebar
    }

    public let drawsSidebar: Bool

    public let drawsInspector: Bool

    public let sidebarCeiling: CGFloat

    public var reach: Reach { drawsSidebar ? .all : .withoutSidebar }

    public static func resolve(
        selection: SidebarSelection,
        hasInspectorSubject: Bool,
        wantsInspector: Bool,
        hidesSidebar: Bool,
        widths: WindowWidths,
        availableWidth: CGFloat
    ) -> WindowColumns {
        let inspector = hasInspectorSubject && selection.workspaceID != nil
        let room = widths.sidebarMaximum(
            sharing: availableWidth, withInspector: inspector && wantsInspector
        )
        return WindowColumns(
            drawsSidebar: room != nil && !hidesSidebar,
            drawsInspector: inspector,
            sidebarCeiling: room ?? widths.sidebarMinimum
        )
    }
}
