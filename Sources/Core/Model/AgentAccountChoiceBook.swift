import Foundation

public struct AgentAccountChoices: Sendable, Hashable {
    public let project: [AgentKind: AgentAccountID]
    public let profile: [AgentKind: AgentAccountID]

    public static let none = AgentAccountChoices()

    public init(
        project: [AgentKind: AgentAccountID] = [:],
        profile: [AgentKind: AgentAccountID] = [:]
    ) {
        self.project = project
        self.profile = profile
    }
}

public struct AgentAccountChoiceBook: Sendable, Hashable {
    public var repos: [RepoID: [AgentKind: AgentAccountID]]
    public var profiles: [ProfileID: [AgentKind: AgentAccountID]]
    public var repoProfiles: [RepoID: ProfileID]
    public var accounts: ProfileAccounts

    public init(
        repos: [RepoID: [AgentKind: AgentAccountID]] = [:],
        profiles: [ProfileID: [AgentKind: AgentAccountID]] = [:],
        repoProfiles: [RepoID: ProfileID] = [:],
        accounts: ProfileAccounts = ProfileAccounts()
    ) {
        self.repos = repos
        self.profiles = profiles
        self.repoProfiles = repoProfiles
        self.accounts = accounts
    }

    public func profile(of repoID: RepoID?, otherwise profileID: ProfileID? = nil) -> ProfileID? {
        repoID.flatMap { repoProfiles[$0] } ?? profileID
    }

    public func reachable(
        _ standings: [AgentAccountStanding], forRepo repoID: RepoID?, otherwise profileID: ProfileID? = nil
    ) -> [AgentAccountStanding] {
        accounts.reachable(standings, from: profile(of: repoID, otherwise: profileID) ?? .initial)
    }

    public func choices(repoID: RepoID?, profileID: ProfileID? = nil) -> AgentAccountChoices {
        let holder = profile(of: repoID, otherwise: profileID).map(accounts.holder(for:))
        return AgentAccountChoices(
            project: repoID.flatMap { repos[$0] } ?? [:],
            profile: holder.flatMap { profiles[$0] } ?? [:]
        )
    }

    public mutating func record(
        _ account: AgentAccountID,
        of provider: AgentKind,
        forProfile id: ProfileID
    ) {
        profiles[id, default: [:]][provider] = account
    }

    public mutating func record(
        _ account: AgentAccountID,
        of provider: AgentKind,
        forRepo id: RepoID
    ) {
        repos[id, default: [:]][provider] = account
    }
}
