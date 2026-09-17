import Foundation

public enum TerminalCommandMemory {
    public static func key(paneID: String) -> String {
        "terminal.pane.\(paneID).command"
    }

    public static let lengthLimit = 500

    static let shells: Set<String> = [
        "sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh", "ash", "nu", "xonsh", "elvish",
    ]

    public static func offerable(_ command: String?, maximumLength: Int = lengthLimit) -> String? {
        guard let command else { return nil }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumLength else { return nil }
        guard !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { return nil }

        let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count == 1, let first = words.first else { return trimmed }
        let name = (String(first) as NSString).lastPathComponent
        return shells.contains(name.hasPrefix("-") ? String(name.dropFirst()) : name) ? nil : trimmed
    }

    public static func remembered(sent: String?, running: String?) -> String? {
        guard running != nil else { return nil }
        return offerable(sent) ?? offerable(running)
    }
}
