import Foundation
@testable import Core

enum SignInShell {
    static let all = ["/bin/sh", "/bin/zsh", "/bin/dash", "/bin/bash", "/bin/ksh"]
        .filter { FileManager.default.isExecutableFile(atPath: $0) }

    static let hostileOpenings = [
        "",
        "IFS=:; ",
        "readonly CLAUDE_X; ",
        #"export LC_ALL=en_US.UTF-8; CLAUDE_BAD=$(printf '\377\376'); export CLAUDE_BAD; "#,
    ]

    static let separatorCapture = "ud_was=$IFS; "

    static let trailer = ##"""
        ; if [ "$IFS" = "$ud_was" ]; then ud_ifs=intact; else ud_ifs=CHANGED; fi
        printf 'ifs=%s pwd=%s\n' "$ud_ifs" "$PWD"
        """##

    static let credentials = LaunchAccountFixture.hostAuth
        + LaunchAccountFixture.credentials
        + LaunchAccountFixture.tokens
        + ["CLAUDE_X", "CLAUDE_BAD"]

    static let inheritedDirectories = [
        "CLAUDE_CONFIG_DIR": "/somewhere/else",
        "CODEX_HOME": "/inherited/codex",
        "GROK_HOME": "/inherited/grok",
    ]

    static let exemptions = ["CLAUDE_CODE_USE_BEDROCK": "1", "ANTHROPIC_MODEL": "claude-sonnet-4-5"]

    static var dirty: [String: String] {
        var variables = Dictionary(uniqueKeysWithValues: credentials.map { ($0, "inherited") })
        variables.merge(inheritedDirectories) { _, directory in directory }
        variables.merge(exemptions) { _, exempt in exempt }
        variables["PATH"] = "/usr/bin:/bin"
        return variables
    }

    static var probe: String {
        (credentials + Array(inheritedDirectories.keys) + Array(exemptions.keys) + ["PATH"])
            .map { "\($0)=${\($0)-unset}" }
            .joined(separator: " ")
    }

    enum Account: Sendable, CaseIterable, CustomStringConvertible {
        case noneAtAll
        case theDefault
        case ofItsOwn

        var description: String {
            switch self {
            case .noneAtAll: "no account"
            case .theDefault: "the default account"
            case .ofItsOwn: "an account of its own"
            }
        }

        func home(in root: URL) -> AgentAccountHome? {
            switch self {
            case .noneAtAll: nil
            case .theDefault: AgentAccountHome.defaultHome(for: .claudeCode, home: root)
            case .ofItsOwn: AgentAccountCreation.plan(
                provider: .claudeCode, label: "Client", existing: [], support: root
            ).home
            }
        }
    }

    struct Case: Sendable, CustomStringConvertible {
        let opening: String
        let account: Account

        var description: String {
            "\(account) after \(opening.isEmpty ? "nothing" : opening)"
        }
    }

    static let cases: [Case] = hostileOpenings.flatMap { opening in
        Account.allCases.map { Case(opening: opening, account: $0) }
    }

    static func reading(of output: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: output.split(whereSeparator: \.isWhitespace).compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        })
    }
}
