import Foundation

public enum AgentAccountEnvironment {
    public static let strippedPrefixes = ["ANTHROPIC", "CLAUDE", "CODEX", "GROK", "OPENAI", "XAI"]

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
        "(" + shellListing + " " + command + ")"
    }

    public static let listingFailure =
        "Unified Dev could not list the variables to clear, so it did not start the agent."

    public static let shellUnsets = "\"$@\""

    public static let listableNameCharacters = "A-Za-z0-9_.-"

    static let shellListing: String = {
        let kept = directoryVariables.sorted().joined(separator: " ")
        let matched = strippedPrefixes.sorted().joined(separator: "|")
        let program = "BEGIN{n=split(\"\(kept)\",k,\" \");for(i=1;i<=n;i++)keep[k[i]]=1;"
            + "for(v in ENVIRON)if(!(v in keep)&&v ~ /^(\(matched))/"
            + "&&v ~ /^[\(listableNameCharacters)]+$/)"
            + "printf \"-u %s \", v}"
        return "ud_unsets=$(LC_ALL=C /usr/bin/awk '\(program)')"
            + " || { echo '\(listingFailure)' >&2; exit 1; };"
            + " eval \"set -- $ud_unsets\";"
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
