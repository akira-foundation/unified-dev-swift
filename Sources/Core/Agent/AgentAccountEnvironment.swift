import Foundation

public enum AgentAccountEnvironment {
    public static let strippedPrefixes = ["ANTHROPIC", "CLAUDE", "OPENAI"]

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

    public static let shellScrub: String = {
        let kept = directoryVariables.sorted().joined(separator: "|")
        let matched = strippedPrefixes.map { $0 + "*" }.joined(separator: "|")
        let names = "/usr/bin/env | /usr/bin/sed -n 's/^\\([A-Za-z_][A-Za-z0-9_]*\\)=.*/\\1/p'"
        return "for ud_name in $(\(names)); do case \"$ud_name\" in "
            + "\(kept)) ;; \(matched)) unset \"$ud_name\" ;; esac; done; "
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
