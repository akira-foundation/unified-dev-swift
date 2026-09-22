import Foundation

public struct BridgeToolbox: Sendable {
    public let handlers: [any BridgeToolHandling]

    public init(handlers: [any BridgeToolHandling]) {
        self.handlers = handlers
    }

    public static let standard = BridgeToolbox(handlers: [
        WhoamiTool(),
        ProjectListTool(),
        ProjectAddTool(),
        ProjectHideTool(),
        ProjectUnhideTool(),
        WorkspaceListTool(),
        ChatListTool(),
        ChatReadTool(),
        WorkspaceDiffTool(),
        WorkspaceRenameTool(),
        QuickPromptListTool(),
        QuickPromptCreateTool(),
        QuickPromptUpdateTool(),
        QuickPromptDeleteTool(),
        AgentListTool(),
        WorkSuggestTool(),
        WorkWithdrawTool(),
    ])

    public func tools(for role: BridgeRole) -> [BridgeTool] {
        handlers.filter { $0.roles.contains(role) }.map(\.tool).sorted { $0.name < $1.name }
    }

    public func handler(named name: String, for role: BridgeRole) -> (any BridgeToolHandling)? {
        handlers.first { $0.tool.name == name && $0.roles.contains(role) }
    }
}
