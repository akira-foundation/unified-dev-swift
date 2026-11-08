import Foundation

public struct AgentAccountChoice: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        case project
        case profile
        case providerDefault
        case noAccount
    }

    public let home: AgentAccountHome?
    public let reason: Reason
    public let isProjectChoiceLost: Bool
    public let isProfileChoiceLost: Bool

    public init(
        home: AgentAccountHome?,
        reason: Reason,
        isProjectChoiceLost: Bool = false,
        isProfileChoiceLost: Bool = false
    ) {
        self.home = home
        self.reason = reason
        self.isProjectChoiceLost = isProjectChoiceLost
        self.isProfileChoiceLost = isProfileChoiceLost
    }

    public static func resolve(
        provider: AgentKind,
        project: AgentAccountID?,
        profile: AgentAccountID? = nil,
        standings: [AgentAccountStanding]
    ) -> AgentAccountChoice {
        let homes = present(in: standings).filter { $0.provider == provider }
        if let project, let home = homes.first(where: { $0.id == project }) {
            return AgentAccountChoice(home: home, reason: .project)
        }
        let projectLost = project != nil
        if let profile, let home = homes.first(where: { $0.id == profile }) {
            return AgentAccountChoice(home: home, reason: .profile, isProjectChoiceLost: projectLost)
        }
        let profileLost = profile != nil
        guard let providerDefault = homes.first(where: \.isDefault) else {
            return AgentAccountChoice(
                home: nil, reason: .noAccount, isProjectChoiceLost: projectLost, isProfileChoiceLost: profileLost
            )
        }
        return AgentAccountChoice(
            home: providerDefault, reason: .providerDefault,
            isProjectChoiceLost: projectLost, isProfileChoiceLost: profileLost
        )
    }

    public static func present(in standings: [AgentAccountStanding]) -> [AgentAccountHome] {
        standings.filter { $0.directoryExists || $0.home.isDefault }.map(\.home)
    }
}
