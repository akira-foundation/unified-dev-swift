import Foundation
@testable import Core

enum AccountFixture {
    static let user = URL(filePath: "/Users/someone")

    static func standing(
        _ home: AgentAccountHome,
        email: String? = nil,
        exists: Bool = true,
        doubt: String? = nil
    ) -> AgentAccountStanding {
        AgentAccountStanding(
            home: home,
            identity: AgentAccountIdentity(email: email),
            cliReport: .unanswered,
            isolationDoubt: doubt,
            directoryExists: exists
        )
    }

    static func extra(_ name: String, provider: AgentKind = .claudeCode) -> AgentAccountHome {
        AgentAccountHome(
            provider: provider,
            id: AgentAccountID(name),
            directory: URL(filePath: "/support/\(provider.rawValue)/\(name)", directoryHint: .isDirectory),
            isDefault: false
        )
    }

    static var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }
    static var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }
    static var work: AgentAccountHome { extra("work") }
    static var personal: AgentAccountHome { extra("personal") }
}
