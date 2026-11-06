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
        switch scope {
        case .profile:
            let runs = outsideProfile ? "this Mac's own login" : "each agent's default account"
            return "Every project in this profile runs \(runs). \(AgentAccountOptions.addAnAccount)"
        case .project:
            let runs = outsideProfile ? "this Mac's own login" : "each agent's default account"
            return "Every workspace and chat in this project runs \(runs). \(AgentAccountOptions.addAnAccount)"
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
            let fallback = outsideProfile ? "this Mac's own login" : "the default \(agent) account"
            if let chosen = own.standing {
                return (runs(chosen, "Every project in this profile runs \(agent) on \(name(chosen, standings)) "
                    + "unless it chooses another."), false)
            }
            if own.isGone {
                return ("The account chosen for \(agent) in this profile is not available, "
                    + "so its projects run \(fallback).", true)
            }
            return ("Every project in this profile runs \(fallback) unless it chooses another.", false)
        case .project:
            let fallback = outsideProfile ? "this Mac's own login" : "its default account"
            if let chosen = own.standing {
                return (runs(chosen, "Every workspace and chat in this project runs \(agent) on "
                    + "\(name(chosen, standings))."), false)
            }
            if own.isGone {
                let rest = profile.standing != nil ? "follows the profile" : "runs \(fallback)"
                return ("The account chosen for \(agent) in this project is not available, "
                    + "so every workspace and chat \(rest).", true)
            }
            if let inherited = profile.standing {
                return (runs(inherited, "Every workspace and chat in this project follows the profile and runs "
                    + "\(agent) on \(name(inherited, standings))."), false)
            }
            if profile.isGone {
                return ("The account chosen for \(agent) in the profile is not available, "
                    + "so every workspace and chat runs \(fallback).", true)
            }
            let runs = outsideProfile ? "this Mac's own login" : "the default \(agent) account"
            return ("Every workspace and chat in this project runs \(runs).", false)
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
