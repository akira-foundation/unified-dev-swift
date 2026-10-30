import Foundation

public enum TerminalLaunchScript {
    public static func shellCommand(
        directory: String, executable: String, unquoted: String = "", arguments: [String]
    ) -> String {
        "cd " + shellQuoted(directory) + " && "
            + command(executable: executable, unquoted: unquoted, arguments: arguments)
    }

    public static func command(executable: String, unquoted: String = "", arguments: [String]) -> String {
        let head = unquoted.isEmpty ? shellQuoted(executable) : shellQuoted(executable) + " " + unquoted
        return ([head] + arguments.map(shellQuoted)).joined(separator: " ")
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
