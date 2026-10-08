import Foundation

public enum ArchiveDecisionGate {
    public enum Decision: Sendable, Equatable {
        case archive
        case ask(ArchiveRequest)
        case refuse(String)
    }

    public static let agentStartedATurn =
        "An agent in this workspace started a turn while you were being asked, and that turn is "
            + "not in git. Stop it or let it finish, then archive."

    public static func resolve(
        pressedWhileChecking: Bool,
        request: ArchiveRequest,
        report: WorkspaceSafetyReport?,
        isAgentMidTurn: Bool
    ) -> Decision {
        if isAgentMidTurn, !request.hazards.isAgentMidTurn { return .refuse(agentStartedATurn) }
        if pressedWhileChecking { return .archive }
        guard let again = request.reconfirmation(isAgentMidTurn: isAgentMidTurn, report: report) else {
            return .archive
        }
        return .ask(again)
    }
}
