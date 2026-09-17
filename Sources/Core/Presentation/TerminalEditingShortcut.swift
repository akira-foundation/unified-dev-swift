public enum TerminalEditingShortcut {
    public enum Input: Equatable, Sendable {
        case text(String)
        case keyEvent
    }

    public static func input(
        key: String,
        isPlainCommand: Bool,
        usesEnhancedKeyboard: Bool
    ) -> Input? {
        guard isPlainCommand, key == "\u{7f}" || key == "\u{8}" else { return nil }
        return usesEnhancedKeyboard ? .keyEvent : .text("\u{15}")
    }
}
