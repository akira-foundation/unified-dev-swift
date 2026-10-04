import Foundation

public enum SidebarGrouping: String, CaseIterable, Sendable, Hashable {
    case projects
    case status

    public static let storageKey = "sidebar.grouping"

    public static let standard: SidebarGrouping = .projects

    public static func resolve(_ stored: String) -> SidebarGrouping {
        SidebarGrouping(rawValue: stored) ?? standard
    }

    public var title: String {
        switch self {
        case .projects: "Project"
        case .status: "Status"
        }
    }

    public var icon: String {
        switch self {
        case .projects: "folder"
        case .status: "list.bullet.indent"
        }
    }

    public var allowsReordering: Bool { self == .projects }

    public var drawsProjectHeaders: Bool { self == .projects }
}
