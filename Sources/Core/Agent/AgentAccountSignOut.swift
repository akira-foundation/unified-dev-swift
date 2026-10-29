import Foundation

public enum AgentAccountSignOut {
    public enum Cause: Sendable, Hashable {
        case endedElsewhere
        case afterSwitch
    }

    public static let measuredWords = "Not logged in"

    public static func isReported(in words: String) -> Bool {
        words.localizedCaseInsensitiveContains(measuredWords)
    }

    public static func cause(afterSwitchingTo switched: AgentAccountID?, failedOn account: AgentAccountID) -> Cause {
        switched == account ? .afterSwitch : .endedElsewhere
    }

    public static func headline(_ cause: Cause, account: String, provider: AgentKind) -> String {
        switch cause {
        case .endedElsewhere:
            "\(account) was signed out somewhere else. Agents already running on it fail on their next "
                + "turn, whatever Unified Dev did."
        case .afterSwitch:
            "\(provider.label) says \(account) is not signed in. When the CLI cannot refresh a saved "
                + "sign-in it removes it, so trying this account may have cost it."
        }
    }

    public static func recovery(provider: AgentKind) -> String {
        "Unified Dev has no sign-in button for an account that already exists. Sign in to it from a "
            + "terminal with its folder as the \(provider.label) config directory, or use another account."
    }
}
