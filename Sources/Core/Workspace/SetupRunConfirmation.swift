import Foundation

public enum SetupRunConfirmation {
    public struct Question: Equatable, Sendable {
        public var title: String
        public var message: String
        public var confirmLabel: String
        public var cancelLabel: String

        public init(title: String, message: String, confirmLabel: String, cancelLabel: String) {
            self.title = title
            self.message = message
            self.confirmLabel = confirmLabel
            self.cancelLabel = cancelLabel
        }
    }

    public static func question(hasRunSetup: Bool, isAgentRunning: Bool) -> Question {
        var message = "Setup runs in the worktree, preparing its submodules and running any configured "
            + "setup script. It can take minutes, and Unified Dev cannot undo what it writes."

        if isAgentRunning {
            message += "\n\nAn agent is mid turn here. Setup does not stop it, so both "
                + "write to this worktree at once."
        }

        return Question(
            title: hasRunSetup ? "Run setup again?" : "Run setup?",
            message: message,
            confirmLabel: hasRunSetup ? "Run Setup Again" : "Run Setup",
            cancelLabel: "Don\u{2019}t Run"
        )
    }
}
