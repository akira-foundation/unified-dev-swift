import Foundation

public enum MenuBarPanelKey {
    public enum Command: Equatable, Sendable {
        case close
        case openSettings
        case quit
    }

    public static let escape = "\u{1B}"

    public static func command(characters: String, modifiers: MenuShortcut.Modifiers) -> Command? {
        if characters == escape { return modifiers.isEmpty ? .close : nil }
        guard modifiers == .command else { return nil }
        switch characters.lowercased() {
        case ",": return .openSettings
        case "q": return .quit
        case "w": return .close
        default: return nil
        }
    }

    public static func shortcut(for command: Command) -> MenuShortcut? {
        switch command {
        case .close: nil
        case .openSettings: MenuShortcut("comma", .command)
        case .quit: .command("q")
        }
    }
}
