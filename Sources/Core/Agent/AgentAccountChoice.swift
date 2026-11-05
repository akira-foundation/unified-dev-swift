import Foundation

public struct AgentAccountChoice: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        case project
        case providerDefault
        case noAccount
    }

    public let home: AgentAccountHome?
    public let reason: Reason
    public let isProjectChoiceLost: Bool

    public init(home: AgentAccountHome?, reason: Reason, isProjectChoiceLost: Bool = false) {
        self.home = home
        self.reason = reason
        self.isProjectChoiceLost = isProjectChoiceLost
    }

    public static func resolve(
        provider: AgentKind,
        project: AgentAccountID?,
        standings: [AgentAccountStanding]
    ) -> AgentAccountChoice {
        let homes = present(in: standings).filter { $0.provider == provider }
        if let project, let home = homes.first(where: { $0.id == project }) {
            return AgentAccountChoice(home: home, reason: .project)
        }
        let isLost = project != nil
        guard let providerDefault = homes.first(where: \.isDefault) else {
            return AgentAccountChoice(home: nil, reason: .noAccount, isProjectChoiceLost: isLost)
        }
        return AgentAccountChoice(home: providerDefault, reason: .providerDefault, isProjectChoiceLost: isLost)
    }

    public static func present(in standings: [AgentAccountStanding]) -> [AgentAccountHome] {
        standings.filter { $0.directoryExists || $0.home.isDefault }.map(\.home)
    }
}
