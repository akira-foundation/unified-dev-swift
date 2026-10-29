import Foundation

public struct AgentAccountSwitch: Sendable, Hashable {
    public enum Refusal: Sendable, Hashable {
        case otherProvider
    }

    public let relaunch: Bool
    public let resume: String?
    public let directory: URL?
    public let losesTurnInFlight: Bool
    public let refusal: Refusal?

    public static func plan(
        session: Session,
        from: AgentAccountHome,
        to: AgentAccountHome,
        isTurnInFlight: Bool
    ) -> AgentAccountSwitch {
        if from.provider != to.provider || session.agentKind != to.provider {
            return AgentAccountSwitch(
                relaunch: false, resume: nil, directory: nil, losesTurnInFlight: false, refusal: .otherProvider
            )
        }
        if from.id == to.id {
            return AgentAccountSwitch(
                relaunch: false, resume: nil, directory: nil, losesTurnInFlight: false, refusal: nil
            )
        }
        return AgentAccountSwitch(
            relaunch: true,
            resume: session.agentSessionID,
            directory: to.directory,
            losesTurnInFlight: isTurnInFlight,
            refusal: nil
        )
    }
}
