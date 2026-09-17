import Foundation

public struct RunScriptMenuItem: Sendable, Hashable {
    public var title: String
    public var subtitle: String
    public var isEnabled: Bool

    private static func subtitle(of script: RunScript, isRunning: Bool, missingFile: String?) -> String {
        if isRunning { return "Running" }
        if let missingFile { return "Missing \(missingFile)" }
        return firstLine(of: script.command)
    }

    public static func make(
        script: RunScript, isRunning: Bool, missingFile: String?
    ) -> RunScriptMenuItem {
        let subtitle = subtitle(of: script, isRunning: isRunning, missingFile: missingFile)
        let hasCommand = !script.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return RunScriptMenuItem(
            title: script.name,
            subtitle: subtitle,
            isEnabled: isRunning || (missingFile == nil && hasCommand)
        )
    }

    static func firstLine(of command: String) -> String {
        let lines = command.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.first { !$0.hasPrefix("#") } ?? lines.first ?? ""
    }
}
