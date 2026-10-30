import Foundation

public enum AgentAccountEnvironment {
    public static let strippedPrefixes = ["ANTHROPIC", "CLAUDE", "GROK", "OPENAI", "XAI"]

    public static let directoryVariables: Set<String> = Set(
        AgentKind.allCases.compactMap(directoryVariable(for:))
    )

    public static func isStripped(_ name: String) -> Bool {
        guard !directoryVariables.contains(name) else { return false }
        return strippedPrefixes.contains { name.hasPrefix($0) }
    }

    public static func apply(_ home: AgentAccountHome?, to environment: [String: String]) -> [String: String] {
        var result = environment.filter { !isStripped($0.key) }
        guard let home, !home.isDefault, let variable = directoryVariable(for: home.provider) else {
            return result
        }
        result[variable] = home.directory.path
        return result
    }

    public static func login(for home: AgentAccountHome?, inheriting inherited: [String: String]) -> [String: String] {
        apply(home, to: Shell.terminalEnvironment(inheriting: inherited))
    }

    public static func codexHome(for home: AgentAccountHome?, inheriting environment: [String: String]) -> String? {
        apply(home, to: environment)["CODEX_HOME"]
    }

    public static func subshell(around command: String) -> String {
        "(IFS=' '; " + command + ")"
    }

    public static let shellUnsets: String = {
        let kept = directoryVariables.sorted().joined(separator: "|")
        let matched = strippedPrefixes.sorted().joined(separator: "|")
        return "$(/usr/bin/env | LC_ALL=C /usr/bin/sed -E -n"
            + " -e '/^(\(kept))=/d'"
            + " -e 's#^((\(matched))[A-Za-z0-9_]*)=.*#-u \\1#p'"
            + " | LC_ALL=C /usr/bin/tr '\\n' ' ')"
    }()

    public static func shellAssignments(for home: AgentAccountHome?) -> [String] {
        guard let home, !home.isDefault, let variable = directoryVariable(for: home.provider) else { return [] }
        return ["\(variable)=\(home.directory.path)"]
    }

    public static func givesADirectory(to provider: AgentKind) -> Bool {
        directoryVariable(for: provider) != nil
    }

    private static func directoryVariable(for provider: AgentKind) -> String? {
        switch provider {
        case .claudeCode: "CLAUDE_CONFIG_DIR"
        case .codex: "CODEX_HOME"
        case .grok: "GROK_HOME"
        case .cursor, .openCode: nil
        }
    }
}
