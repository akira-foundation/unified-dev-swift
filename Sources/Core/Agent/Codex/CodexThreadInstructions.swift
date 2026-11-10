import Foundation

public enum CodexThreadInstructions {
    static let readingOtherChats = """
        This chat runs in a workspace of Unified Dev, which connects it to the MCP server \
        \(BridgeRegistration.serverName). Other chats in this workspace can be read: when asked \
        about another chat, or what another agent said or decided, call chat_list to find it and \
        chat_read to read it, before saying you cannot see it. If those tools are not listed \
        directly, look them up by name among the tools available to you.
        """

    public static func text(inWorkspace: Bool, orchestrates: Bool, hasBridge: Bool) -> String? {
        guard inWorkspace else { return AskConversation.instructions }
        let parts = [orchestrates ? OrchestratorRole.instructions : nil, hasBridge ? readingOtherChats : nil]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }
}
