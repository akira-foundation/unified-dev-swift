import Testing
@testable import Core

@Suite("What a workspace with no name of its own is called")
struct WorkspaceStartPlanTests {
    @Test("a typed branch names a terminal workspace")
    func typedBranchNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: "spike/perf", claimedSea: "Coral Sea"
        ) == "spike/perf")
    }

    @Test("otherwise the sea does")
    func seaNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: nil, claimedSea: "Coral Sea"
        ) == "Coral Sea")
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: "", claimedSea: "Coral Sea"
        ) == "Coral Sea")
    }

    @Test("with neither, nothing is claimed to be the name")
    func neitherNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: nil, claimedSea: nil
        ) == nil)
    }

    @Test("a start with no name of its own is named after the sea it claimed, unless a chat has a task")
    func unnamedStarts() {
        #expect(WorkspaceStartPlan.unnamedName(
            isChatWorkspace: true, hasTask: false, userSuppliedBranch: nil, claimedSea: "Coral Sea"
        ) == "Coral Sea")
        #expect(WorkspaceStartPlan.unnamedName(
            isChatWorkspace: true, hasTask: true, userSuppliedBranch: nil, claimedSea: "Coral Sea"
        ) == nil)
        #expect(WorkspaceStartPlan.unnamedName(
            isChatWorkspace: false, hasTask: true, userSuppliedBranch: "spike/x", claimedSea: nil
        ) == "spike/x")
        #expect(WorkspaceStartPlan.unnamedName(
            isChatWorkspace: false, hasTask: false, userSuppliedBranch: nil, claimedSea: "Coral Sea"
        ) == "Coral Sea")
    }
}

@Suite("What a workspace start opens on")
struct WorkspaceStartModeTests {
    @Test("chat and CLI starts run agents")
    func agentStartsRunAgents() {
        #expect(WorkspaceStartMode.chat.runsAnAgent)
        #expect(WorkspaceStartMode.claudeCLI.runsAnAgent)
        #expect(WorkspaceStartMode.codexCLI.runsAnAgent)
        #expect(!WorkspaceStartMode.terminal.runsAnAgent)
    }

    @Test("CLI starts retain their backend and agent tab")
    func cliStartsUseAgentTabs() {
        #expect(WorkspaceStartMode.claudeCLI.cliAgentKind == .claudeCode)
        #expect(WorkspaceStartMode.codexCLI.cliAgentKind == .codex)
        for mode in [WorkspaceStartMode.claudeCLI, .codexCLI] {
            #expect(mode.pane == .chat)
        }
        #expect(WorkspaceStartMode.chat.cliAgentKind == nil)
        #expect(WorkspaceStartMode.terminal.cliAgentKind == nil)
    }
}

@Suite("What a new workspace is named")
struct WorkspaceNameTests {
    @Test("a name that was settled wins over everything")
    func settledNameWins() {
        #expect(WorkspaceStartPlan.name(
            supplied: "Harbour", checkout: nil, prompt: "Fix the login flow"
        ) == "Harbour")
        #expect(WorkspaceStartPlan.name(
            supplied: "Harbour",
            checkout: .branch(ExistingBranch(name: "feature/x", isLocal: true)),
            prompt: ""
        ) == "Harbour")
    }

    @Test("an empty name is no name")
    func emptyNameIsNoName() {
        #expect(WorkspaceStartPlan.name(
            supplied: "", checkout: nil, prompt: "Fix the login flow"
        ) == "Fix the login flow")
    }

    @Test("a checkout brings its own name")
    func checkoutBringsItsOwn() {
        #expect(WorkspaceStartPlan.name(
            supplied: nil,
            checkout: .branch(ExistingBranch(name: "feature/x", isLocal: true)),
            prompt: "ignored"
        ) == "feature/x")
    }

    @Test("nothing settled falls back to the task, and an empty task still has a name")
    func fallsBackToTheTask() {
        #expect(WorkspaceStartPlan.name(
            supplied: nil, checkout: nil, prompt: "Fix the login flow"
        ) == "Fix the login flow")
        #expect(!WorkspaceStartPlan.name(supplied: nil, checkout: nil, prompt: "").isEmpty)
    }
}
