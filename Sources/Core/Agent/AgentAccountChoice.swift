import Foundation

public struct AgentAccountChoice: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        case workspace
        case project
        case providerDefault
        case chosenAccountIsGone
        case noAccount
    }

    public let home: AgentAccountHome?
    public let reason: Reason

    public init(home: AgentAccountHome?, reason: Reason) {
        self.home = home
        self.reason = reason
    }

    public static func resolve(
        provider: AgentKind,
        workspace: AgentAccountID?,
        project: AgentAccountID?,
        standings: [AgentAccountStanding]
    ) -> AgentAccountChoice {
        let homes = standings.map(\.home).filter { $0.provider == provider }
        let providerDefault = homes.first(where: \.isDefault)

        if let chosen = workspace {
            return named(chosen, as: .workspace, in: homes, fallback: providerDefault)
        }
        if let chosen = project {
            return named(chosen, as: .project, in: homes, fallback: providerDefault)
        }
        guard let providerDefault else { return AgentAccountChoice(home: nil, reason: .noAccount) }
        return AgentAccountChoice(home: providerDefault, reason: .providerDefault)
    }

    private static func named(
        _ id: AgentAccountID,
        as reason: Reason,
        in homes: [AgentAccountHome],
        fallback: AgentAccountHome?
    ) -> AgentAccountChoice {
        if let home = homes.first(where: { $0.id == id }) {
            return AgentAccountChoice(home: home, reason: reason)
        }
        return AgentAccountChoice(home: fallback, reason: .chosenAccountIsGone)
    }
}
