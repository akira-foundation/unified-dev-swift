import SwiftUI
/// Only visible destinations belong here, so navigation cannot retain removed panes.
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

    /// The colour of the tile the sidebar draws the glyph on, which is the pattern System
    /// Settings uses for every row. Grouped with the sections, so the rows of a section are
    /// neighbours on the wheel rather than unrelated colours.
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

/// One row of the settings sidebar: the pane's glyph on a filled tile, and its name.
///
/// Drawn rather than left to `Label`, because `Label` puts a bare symbol in the icon slot and no
/// style fills it. Twenty points at a five point corner with the glyph at eleven, measured off the
/// rows in System Settings.
struct SettingsTabLabel: View {
    var tab: SettingsTab

    var body: some View {
        Label {
            Text(tab.title)
        } icon: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(tab.tint)
                .frame(width: 20, height: 20)
                .overlay {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
        }
    }
}

