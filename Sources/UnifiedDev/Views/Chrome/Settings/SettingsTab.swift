import SwiftUI
import Core
enum SettingsTab: String, CaseIterable, SettingsPage {
    case general
    case appearance
    case menuBar
    case notifications
    case agents
    case sessions
    case permissions
    case prompts
    case terminal
    case commandLine

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .menuBar: "Menu Bar"
        case .notifications: "Notifications"
        case .agents: "Agents"
        case .sessions: "Sessions"
        case .permissions: "Permissions"
        case .prompts: "Prompts"
        case .terminal: "Terminal"
        case .commandLine: "Command Line"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gear"
        case .appearance: "paintbrush"
        case .menuBar: "menubar.rectangle"
        case .notifications: "bell"
        case .agents: "person.2"
        case .sessions: "bubble.left.and.bubble.right"
        case .permissions: "hand.raised"
        case .prompts: "text.bubble"
        case .terminal: "terminal"
        case .commandLine: "link"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: Palette.accentFill
        case .menuBar: .indigo
        case .notifications: .red
        case .agents: .blue
        case .sessions: .teal
        case .permissions: .orange
        case .prompts: .pink
        case .terminal: Color(nsColor: .darkGray)
        case .commandLine: .green
        }
    }

    var glyph: Color { self == .appearance ? Palette.onAccentFill : .white }

    static let sections = [
        SettingsSidebarSection("Unified Dev", pages: [SettingsTab.general, .appearance, .menuBar, .notifications]),
        SettingsSidebarSection("Agents", pages: [SettingsTab.agents, .sessions, .permissions, .prompts]),
        SettingsSidebarSection("Terminal & connections", pages: [SettingsTab.terminal, .commandLine]),
    ]
}
