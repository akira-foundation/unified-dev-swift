import SwiftUI
enum SettingsTab: String, Hashable, CaseIterable {
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
}

struct SettingsTabLabel: View {
    var tab: SettingsTab

    var body: some View {
        SettingsSidebarLabel(title: tab.title, systemImage: tab.systemImage, tint: tab.tint)
    }
}
