import Foundation

public enum MenuBarSummary {
    public struct Segment: Equatable, Sendable {
        public let symbolName: String
        public let count: Int
        public let label: String

        public init(symbolName: String, count: Int, label: String) {
            self.symbolName = symbolName
            self.count = count
            self.label = label
        }
    }

    public static let waitingSymbol = "hand.raised.fill"
    public static let runningSymbol = "circle.fill"
    public static let unreadSymbol = "envelope.fill"

    public static func segments(
        waiting: Int,
        unread: Int,
        showsWaiting: Bool = true,
        showsUnread: Bool = true
    ) -> [Segment] {
        var segments: [Segment] = []
        if showsWaiting, waiting > 0 {
            segments.append(
                Segment(symbolName: waitingSymbol, count: waiting, label: "Agents waiting on you")
            )
        }
        if showsUnread, unread > 0 {
            segments.append(
                Segment(symbolName: unreadSymbol, count: unread, label: "Unread results")
            )
        }
        return segments
    }

    public static func tooltip(waiting: Int, unread: Int) -> String {
        var lines: [String] = []
        if waiting > 0 {
            lines.append("\(Counted.of(waiting, "agent")) waiting on you")
        }
        if unread > 0 {
            lines.append(Counted.of(unread, "unread result"))
        }
        return lines.isEmpty ? idleTooltip : lines.joined(separator: ", ")
    }

    public static let idleTooltip = "Nothing waiting on you"

    public static let emptyTitle = "No agents running"

    public static let waitingHeading = "Waiting on you"

    public static let runningHeading = "Running"

    public static let unreadHeading = "Finished"

    public struct Section: Equatable, Sendable {
        public let heading: String
        public let symbolName: String
        public let label: String
        public let workspaces: [Workspace]

        public init(heading: String, symbolName: String, label: String, workspaces: [Workspace]) {
            self.heading = heading
            self.symbolName = symbolName
            self.label = label
            self.workspaces = workspaces
        }
    }

    public static func sections(
        in workspaces: [Workspace],
        isRunning: (Workspace) -> Bool,
        isAwaitingPermission: (Workspace) -> Bool
    ) -> [Section] {
        var sections: [Section] = []

        let waiting = workspaces.filter(isAwaitingPermission)
        if !waiting.isEmpty {
            sections.append(Section(
                heading: waitingHeading,
                symbolName: waitingSymbol,
                label: "Agent waiting on you",
                workspaces: waiting
            ))
        }

        let unread = workspaces.filter { DockBadge.hasUnreadResult($0, isRunning: isRunning) }
        if !unread.isEmpty {
            sections.append(Section(
                heading: unreadHeading,
                symbolName: unreadSymbol,
                label: "Unread",
                workspaces: unread
            ))
        }

        let running = workspaces.filter { isRunning($0) && !isAwaitingPermission($0) }
        if !running.isEmpty {
            sections.append(Section(
                heading: runningHeading,
                symbolName: runningSymbol,
                label: "Agent running",
                workspaces: running
            ))
        }

        return sections
    }
}
