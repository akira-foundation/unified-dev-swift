import Foundation

public enum AgentAccountSignInAgain {
    public static let actionTitle = "Sign In Again"

    static func isOffered(
        for standing: AgentAccountStanding,
        userHome: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        !standing.home.isDefault
            && !standing.home.isTheCliOwnDirectory(under: userHome)
            && standing.directoryExists
            && standing.isolationIsGuaranteed
    }

    public static func notice(account: String, provider: AgentKind) -> String {
        "This signs \(account) in to \(provider.label) again, in the folder it already uses. Its transcripts stay where they are."
    }
}
