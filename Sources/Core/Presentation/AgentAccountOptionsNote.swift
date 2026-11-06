import Foundation

enum AgentAccountOptionsNote {
    enum Reach {
        case none
        case present(AgentAccountStanding)
        case gone

        init(_ id: AgentAccountID?, in mine: [AgentAccountStanding]) {
            guard let id else { self = .none; return }
            if let found = mine.first(where: { $0.home.id == id }) { self = .present(found) } else { self = .gone }
        }

        var standing: AgentAccountStanding? {
            if case .present(let standing) = self { return standing }
            return nil
        }

        var isGone: Bool {
            if case .gone = self { return true }
            return false
        }
    }

    static func nothingToOffer(_ scope: AgentAccountOptions.Scope, outsideProfile: Bool) -> String {
        let add = AgentAccountOptions.addAnAccount
        switch scope {
        case .profile where outsideProfile:
            return "No project in this profile starts an agent that needs an account until it has one. \(add)"
        case .profile:
            return "Every project in this profile runs each agent's default account. \(add)"
        case .project where outsideProfile:
            return "No workspace or chat in this project starts an agent that needs an account until it has one. \(add)"
        case .project:
            return "Every workspace and chat in this project runs each agent's default account. \(add)"
        }
    }

    static func make(
        scope: AgentAccountOptions.Scope,
        agent: String,
        own: Reach,
        profile: Reach,
        standings: [AgentAccountStanding],
        outsideProfile: Bool
    ) -> (text: String, warns: Bool) {
        switch scope {
        case .profile:
            if let chosen = own.standing {
                return (runs(chosen, "Every project in this profile runs \(agent) on \(name(chosen, standings)) "
                    + "unless it chooses another."), false)
            }
            if own.isGone {
                let rest = outsideProfile
                    ? "do not start \(agent) until one is chosen" : "run the default \(agent) account"
                return ("The account chosen for \(agent) in this profile is not available, so its projects \(rest).", true)
            }
            if outsideProfile {
                return ("No project in this profile starts \(agent) unless it chooses an account.", true)
            }
            return ("Every project in this profile runs the default \(agent) account unless it chooses another.", false)
        case .project:
            let fallback = outsideProfile ? "does not start \(agent)" : "runs its default account"
            if let chosen = own.standing {
                return (runs(chosen, "Every workspace and chat in this project runs \(agent) on "
                    + "\(name(chosen, standings))."), false)
            }
            if own.isGone {
                let rest = profile.standing != nil ? "follows the profile" : fallback
                return ("The account chosen for \(agent) in this project is not available, "
                    + "so every workspace and chat \(rest).", true)
            }
            if let inherited = profile.standing {
                return (runs(inherited, "Every workspace and chat in this project follows the profile and runs "
                    + "\(agent) on \(name(inherited, standings))."), false)
            }
            if profile.isGone {
                return ("The account chosen for \(agent) in the profile is not available, "
                    + "so every workspace and chat \(fallback).", true)
            }
            if outsideProfile {
                return ("No workspace or chat in this project starts \(agent) until an account is chosen.", true)
            }
            return ("Every workspace and chat in this project runs the default \(agent) account.", false)
        }
    }

    private static func name(_ standing: AgentAccountStanding, _ standings: [AgentAccountStanding]) -> String {
        AgentAccountNames.reference(to: standing, among: standings)
    }

    private static func runs(_ standing: AgentAccountStanding, _ sentence: String) -> String {
        guard !standing.home.isDefault, let doubt = standing.isolationDoubt else { return sentence }
        return "\(sentence) \(doubt)"
    }
}
