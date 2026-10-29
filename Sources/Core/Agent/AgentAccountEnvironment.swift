import Foundation

public enum AgentAccountEnvironment {
    public static let stripped: Set<String> = [
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "ANTHROPIC_BASE_URL",
        "CLAUDE_CODE_USER_EMAIL",
        "CLAUDE_CODE_ACCOUNT_UUID",
        "CLAUDE_CODE_ORGANIZATION_UUID",
        "CLAUDECODE",
        "CLAUDE_CODE_ENTRYPOINT",
        "CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH",
        "CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH",
        "CLAUDE_CODE_SESSION_ACCESS_TOKEN",
        "CLAUDE_CODE_HOST_AUTH_ENV_VAR",
        "CLAUDE_CODE_HOST_CREDS_FILE",
        "CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST",
        "CLAUDE_CODE_MESSAGING_SOCKET",
        "CLAUDE_CODE_MESSAGING_TOKEN",
        "CLAUDE_CODE_EXECPATH",
    ]

    public static func apply(_ home: AgentAccountHome?, to environment: [String: String]) -> [String: String] {
        var result = environment.filter { !stripped.contains($0.key) }
        guard let home, !home.isDefault, let variable = directoryVariable(for: home.provider) else {
            return result
        }
        result[variable] = home.directory.path
        return result
    }

    public static func codexHome(for home: AgentAccountHome?, inheriting environment: [String: String]) -> String? {
        apply(home, to: environment)["CODEX_HOME"]
    }

    public static var shellUnsets: [String] {
        stripped.sorted().flatMap { ["-u", $0] }
    }

    public static func shellAssignments(for home: AgentAccountHome?) -> [String] {
        guard let home, !home.isDefault, let variable = directoryVariable(for: home.provider) else { return [] }
        return ["\(variable)=\(home.directory.path)"]
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
