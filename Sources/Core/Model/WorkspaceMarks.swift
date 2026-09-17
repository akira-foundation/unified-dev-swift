import Foundation

public enum UnreadMarkAction: String, Sendable, Hashable, CaseIterable {
    case markUnread
    case markRead

    public var title: String {
        switch self {
        case .markUnread: "Mark as Unread"
        case .markRead: "Mark as Read"
        }
    }

    public var unread: Bool {
        self == .markUnread
    }
}

public enum WorkspaceUnreadMark {
    public static func action(for workspace: Workspace) -> UnreadMarkAction? {
        guard workspace.state == .active else { return nil }
        return workspace.unread ? .markRead : .markUnread
    }

    public static func isUnread(_ workspace: Workspace) -> Bool {
        action(for: workspace) == .markRead
    }
}

public struct WorkspaceColour: Identifiable, Sendable, Hashable, Codable {
    public let name: String
    public let hex: String

    public var id: String { hex }

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }

    public static let all: [WorkspaceColour] = [
        WorkspaceColour(name: "Red", hex: "E2725B"),
        WorkspaceColour(name: "Orange", hex: "E06C2A"),
        WorkspaceColour(name: "Yellow", hex: "D9A21B"),
        WorkspaceColour(name: "Lime", hex: "5B8C2A"),
        WorkspaceColour(name: "Green", hex: "22A06B"),
        WorkspaceColour(name: "Teal", hex: "2FA8A8"),
        WorkspaceColour(name: "Blue", hex: "4C8DF6"),
        WorkspaceColour(name: "Purple", hex: "9B6DE0"),
        WorkspaceColour(name: "Pink", hex: "D8608C"),
        WorkspaceColour(name: "Grey", hex: "6C7A89"),
    ]

    public static func named(_ hex: String) -> WorkspaceColour? {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

public extension Workspace {
    var colourMark: HexColor? {
        colour.flatMap(HexColor.init(hex:))
    }

    var colourDescription: String? {
        guard let colour, colourMark != nil else { return nil }
        return WorkspaceColour.named(colour)?.name ?? "#\(colour)"
    }
}
