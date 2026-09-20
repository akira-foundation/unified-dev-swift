import Testing
@testable import Core

@Suite("Bridge workspace scope")
struct BridgeWorkspaceScopeTests {
    @Test("the refusal names the tool, what it would have done, and what is missing")
    func theRefusalIsOneSentence() {
        #expect(
            BridgeWorkspaceScope.refusal(tool: "pane_open", doing: "opens a pane in")
                == "pane_open opens a pane in the workspace you are in, and this connection is "
                + "not speaking for one."
        )
        #expect(
            BridgeWorkspaceScope.refusal(tool: "workspace_rename", doing: "renames")
                == "workspace_rename renames the workspace you are in, and this connection is not "
                + "speaking for one."
        )
    }

    @Test("the trouble enums say it the same way the tools do")
    func theTroubleEnumsAgree() {
        #expect(
            CrewToolTrouble.notInAWorkspace(tool: "agent_list").sentence
                == BridgeWorkspaceScope.refusal(
                    tool: "agent_list", doing: "is about the agents working in"
                )
        )
        #expect(
            WorkspaceRenameTrouble.notInAWorkspace.sentence
                == BridgeWorkspaceScope.refusal(tool: "workspace_rename", doing: "renames")
        )
    }

    @Test("only a workspace agent is on the workspace-scoped gate")
    func onlyAWorkspaceAgentIsOnTheGate() {
        #expect(BridgeWorkspaceScope.roles == [.workspace])
    }

    @Test("every workspace-scoped tool is listed to a workspace agent and to nobody else")
    func theGateIsOnAllOfThem() {
        let handlers: [any BridgeToolHandling] = [
            PaneOpenTool { _, _ in .opened("") },
            PaneSplitTool { _, _, _, _ in .opened("") },
            PaneCloseTool { _, _ in .opened("") },
            PaneRenameTool { _, _, _ in .opened("") },
            PaneListTool { _ in nil },
            ChatListTool(),
            ChatReadTool(),
            WorkspaceTabsTool { _ in nil },
            WorkspaceTabSelectTool { _, _ in .refused("") },
            MediaShowTool { _, _ in .refused("") },
            TerminalStartTool { _, _ in .opened("") },
            TerminalReadTool { _, _ in .refused("") },
            TerminalWriteTool { _, _ in .refused("") },
            TerminalSendKeyTool { _, _ in .refused("") },
            BrowserReadTool { _, _ in .refused("") },
            BrowserReloadTool { _, _ in .refused("") },
            BrowserGoTool { _, _ in .refused("") },
            BrowserScreenshotTool { _, _ in .refused("") },
            BrowserScrollTool { _, _ in .refused("") },
            BrowserTextTool { _, _ in .refused("") },
        ]
        let toolbox = BridgeToolbox(handlers: handlers)
        #expect(toolbox.tools(for: .workspace).count == handlers.count)
        #expect(toolbox.tools(for: .owner).isEmpty)
    }
}
