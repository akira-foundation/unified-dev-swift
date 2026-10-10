import Foundation

public enum AgentQuestionDisclosure {
    public static func isOpen(isSettled: Bool, wasReopened: Bool) -> Bool {
        !isSettled || wasReopened
    }

    public static func reopenTitle(isOpen: Bool) -> String {
        isOpen ? "Hide the options" : "Show the options again"
    }
}
