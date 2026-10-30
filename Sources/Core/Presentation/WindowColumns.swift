import CoreGraphics

public struct WindowColumns: Equatable, Sendable {
    public enum Reach: Equatable, Sendable, CaseIterable {
        case all
        case withoutSidebar

        public var showsCentre: Bool { self == .all || self == .withoutSidebar }
    }

    public let fitsSidebar: Bool

    public let drawsSidebar: Bool

    public let drawsInspector: Bool

    public let sidebarCeiling: CGFloat

    public var reach: Reach { drawsSidebar ? .all : .withoutSidebar }

    public static func resolve(
        selection: SidebarSelection,
        hasInspectorSubject: Bool,
        reservesInspectorRoom: Bool,
        hidesSidebar: Bool,
        widths: WindowWidths,
        availableWidth: CGFloat
    ) -> WindowColumns {
        let room = widths.sidebarMaximum(
            sharing: availableWidth, withInspector: reservesInspectorRoom
        )
        return WindowColumns(
            fitsSidebar: room != nil,
            drawsSidebar: room != nil && !hidesSidebar,
            drawsInspector: hasInspectorSubject && selection.workspaceID != nil,
            sidebarCeiling: room ?? widths.sidebarMinimum
        )
    }
}
