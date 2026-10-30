import Foundation

public struct AgentAccountChoice: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        case workspace
        case project
        case providerDefault
        case noAccount
    }

    public enum Level: Sendable, Hashable {
        case workspace
        case project
    }

    public let home: AgentAccountHome?
    public let reason: Reason
    public let lost: Set<Level>

    public init(home: AgentAccountHome?, reason: Reason, lost: Set<Level> = []) {
        self.home = home
        self.reason = reason
        self.lost = lost
    }

    public static func resolve(
        provider: AgentKind,
        workspace: AgentAccountID?,
        project: AgentAccountID?,
        standings: [AgentAccountStanding]
    ) -> AgentAccountChoice {
        let homes = present(in: standings).filter { $0.provider == provider }
        let chain: [(id: AgentAccountID?, level: Level, reason: Reason)] = [
            (workspace, .workspace, .workspace),
            (project, .project, .project)
        ]

        var lost: Set<Level> = []
        for step in chain {
            guard let id = step.id else { continue }
            guard let home = homes.first(where: { $0.id == id }) else {
                lost.insert(step.level)
                continue
            }
            return AgentAccountChoice(home: home, reason: step.reason, lost: lost)
        }

        guard let providerDefault = homes.first(where: \.isDefault) else {
            return AgentAccountChoice(home: nil, reason: .noAccount, lost: lost)
        }
        return AgentAccountChoice(home: providerDefault, reason: .providerDefault, lost: lost)
    }

    public static func present(in standings: [AgentAccountStanding]) -> [AgentAccountHome] {
        standings.filter { $0.directoryExists || $0.home.isDefault }.map(\.home)
    }
}
