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
        let chain: [(id: AgentAccountID?, reason: Reason)] = [(workspace, .workspace), (project, .project)]

        var lostAChoice = false
        for level in chain {
            guard let id = level.id else { continue }
            guard let home = homes.first(where: { $0.id == id }) else {
                lostAChoice = true
                continue
            }
            return AgentAccountChoice(home: home, reason: lostAChoice ? .chosenAccountIsGone : level.reason)
        }

        let providerDefault = homes.first(where: \.isDefault)
        if lostAChoice { return AgentAccountChoice(home: providerDefault, reason: .chosenAccountIsGone) }
        guard let providerDefault else { return AgentAccountChoice(home: nil, reason: .noAccount) }
        return AgentAccountChoice(home: providerDefault, reason: .providerDefault)
    }
}
