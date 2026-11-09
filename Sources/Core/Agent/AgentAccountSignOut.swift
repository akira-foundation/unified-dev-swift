import Foundation

public enum AgentAccountSignOut {
    public enum Cause: Sendable, Hashable {
        case notSignedIn
        case afterSwitch
    }

    public enum Observation: Sendable, Equatable {
        case none
        case signedOut
        case working
    }

    public static let measuredWords = "Not logged in"
    public static let measuredTerminalReason = "api_error"

    public static func observe(
        _ result: AgentResult,
        isReplayingPastTurn: Bool,
        isReconcilingPresentation: Bool
    ) -> Observation {
        guard !isReplayingPastTurn, !isReconcilingPresentation else { return .none }
        if result.succeeded { return .working }
        return isReported(by: result) ? .signedOut : .none
    }

    static func isReported(by result: AgentResult) -> Bool {
        result.terminalReason == measuredTerminalReason
            && result.summary
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .range(of: measuredWords, options: [.anchored, .caseInsensitive]) != nil
    }

    public static func headline(_ cause: Cause, account: String, provider: AgentKind) -> String {
        switch cause {
        case .notSignedIn:
            "\(provider.label) says \(account) is not signed in. It may have been signed out somewhere else "
                + "or its sign-in may have expired. Agents already running on it fail on their next turn, "
                + "whatever Unified Dev did."
        case .afterSwitch:
            "\(provider.label) says \(account) is not signed in. When the CLI cannot refresh a saved "
                + "sign-in it removes it, so trying this account may have cost it."
        }
    }

    public static func recovery(provider: AgentKind, standing: AgentAccountStanding? = nil) -> String {
        guard let standing, !standing.home.isDefault, !AgentAccountSignInAgain.isOffered(for: standing) else {
            return "Sign in to it again in Settings, under Agents, \(provider.label)."
        }
        return "Unified Dev cannot sign this account in again, because its folder is gone or does not keep its "
            + "login apart. Remove it in Settings, under Agents, \(provider.label)."
    }
}
