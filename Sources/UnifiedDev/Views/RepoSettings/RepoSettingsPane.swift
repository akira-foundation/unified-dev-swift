import SwiftUI

enum RepoSettingsPane: String, CaseIterable, SettingsPage {
    case project
    case agents
    case workspaces
    case scripts
    case instructions

    var title: String {
        switch self {
        case .project: "Project"
        case .agents: "Agents"
        case .workspaces: "Workspaces"
        case .scripts: "Scripts"
        case .instructions: "Instructions"
        }
    }

    var systemImage: String {
        switch self {
        case .project: "folder"
        case .agents: "person.crop.circle"
        case .workspaces: "square.stack.3d.up"
        case .scripts: "terminal"
        case .instructions: "text.book.closed"
        }
    }

    var tint: Color {
        switch self {
        case .project: .gray
        case .agents: .indigo
        case .workspaces: Palette.accentFill
        case .scripts: Color(nsColor: .darkGray)
        case .instructions: .teal
        }
    }

    var glyph: Color { self == .workspaces ? Palette.onAccentFill : .white }

    static var requested: RepoSettingsPane? {
        guard let named = ProcessInfo.processInfo.environment["UD_PANE"] else { return nil }
        return RepoSettingsPane(rawValue: named)
    }
}
