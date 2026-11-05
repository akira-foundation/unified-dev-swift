import Foundation
import Testing
@testable import Core

@Suite("The menu bar and the active profile")
struct ProfileMenuBarTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func workspace(_ name: String) -> Workspace {
        Workspace(repoID: RepoID(name), name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main", setupState: .succeeded)
    }

    private func input(
        workspaces: [Workspace],
        running: Set<WorkspaceID> = [],
        waiting: Set<WorkspaceID> = [],
        agents: [WorkspaceID: Int] = [:],
        askIsWorking: Bool = false,
        hold: KeepAwake.Hold = .none,
        quotas: [AgentQuota] = []
    ) -> MenuBarPanelContent.Input {
        MenuBarPanelContent.Input(
            workspaces: workspaces,
            running: running,
            waiting: waiting,
            runningAgents: agents.values.reduce(0, +) + (askIsWorking ? 1 : 0),
            quotas: quotas,
            accounts: [:],
            unanswered: [],
            withoutLimits: [],
            lastReported: [:],
            layout: UsageLayout(),
            hold: hold,
            now: now,
            agentsByWorkspace: agents,
            askIsWorking: askIsWorking
        )
    }

    @Test("the menu bar shows only the profile's workspaces")
    func showsOnlyTheProfile() {
        let mine = workspace("mine")
        let waitingHere = workspace("waiting-here")
        let hidden = workspace("hidden")
        let hiddenWaiting = workspace("hidden-waiting")

        let scoped = input(
            workspaces: [mine, waitingHere, hidden, hiddenWaiting],
            running: [mine.id, hidden.id],
            waiting: [waitingHere.id, hiddenWaiting.id],
            agents: [mine.id: 2, hidden.id: 5]
        ).scoped(to: [mine, waitingHere])

        #expect(scoped.workspaces.map(\.id) == [mine.id, waitingHere.id])
        #expect(scoped.running == [mine.id])
        #expect(scoped.waiting == [waitingHere.id])
        #expect(scoped.runningAgents == 2)

        let content = MenuBarPanelContent.make(scoped)
        #expect(Set(content.agents.map(\.id)) == [mine.id, waitingHere.id])
        #expect(content.sentence.hasPrefix("2 agents running in 1 workspace. 1 agent waiting on you."))
    }

    @Test("keep awake still counts agents in every profile")
    func keepAwakeCountsEveryProfile() {
        let hidden = workspace("hidden")
        let hold = KeepAwake.Hold.of(session: nil, whileAgentsRun: true, runningCount: 1, at: now)

        let scoped = input(
            workspaces: [hidden], running: [hidden.id], agents: [hidden.id: 1], hold: hold
        ).scoped(to: [])

        #expect(scoped.hold.isOn)
        let content = MenuBarPanelContent.make(scoped)
        #expect(content.badges.contains(.awake))
        #expect(!content.badges.contains(.running))
        #expect(content.agents.isEmpty)
    }

    @Test("an agent in a hidden profile lights neither the running nor the waiting badge")
    func hiddenAgentLightsNoBadge() {
        let hidden = workspace("hidden")
        let hiddenWaiting = workspace("hidden-waiting")

        let content = MenuBarPanelContent.make(input(
            workspaces: [hidden, hiddenWaiting],
            running: [hidden.id],
            waiting: [hiddenWaiting.id],
            agents: [hidden.id: 3]
        ).scoped(to: []))

        #expect(content.badges.isEmpty)
    }

    @Test("the Ask chat belongs to no profile, so it stays counted")
    func askStaysCounted() {
        let hidden = workspace("hidden")

        let scoped = input(
            workspaces: [hidden], running: [hidden.id], agents: [hidden.id: 1], askIsWorking: true
        ).scoped(to: [])

        #expect(scoped.runningAgents == 1)
        #expect(MenuBarPanelContent.make(scoped).badges == [.running])
    }

    @Test("quotas stay global until accounts are scoped")
    func quotasStayGlobal() {
        let week = QuotaWindow.lasting(604_800, key: "primary")
        let quota = AgentQuota(
            provider: .codex, window: week, measure: .fraction(1), resetsAt: now.addingTimeInterval(60), observedAt: now
        )

        let content = MenuBarPanelContent.make(input(workspaces: [], quotas: [quota]).scoped(to: []))

        #expect(content.badges.contains(.limitReached))
    }
}

@Suite("Agents counted per workspace")
struct AgentsByWorkspaceTests {
    private let first = WorkspaceID("first")
    private let second = WorkspaceID("second")

    @Test("each working session counts in its own workspace, and one waiting does not count")
    func sessionsCountWhereTheyRun() {
        let stored = [
            SessionActivity(sessionID: SessionID("a"), workspaceID: first, state: .running),
            SessionActivity(sessionID: SessionID("b"), workspaceID: first, state: .running),
            SessionActivity(sessionID: SessionID("c"), workspaceID: second, state: .waiting),
        ]

        let counts = AgentTurns.agentsByWorkspace(
            stored: stored, live: [], runningWorkspaces: [first], waitingWorkspaces: [second]
        )

        #expect(counts == [first: 2])
    }

    @Test("a workspace running with no session on record still counts as one")
    func terminalWorkspaceCountsOne() {
        let counts = AgentTurns.agentsByWorkspace(
            stored: [], live: [], runningWorkspaces: [first], waitingWorkspaces: []
        )

        #expect(counts == [first: 1])
    }

    @Test("what a live turn says overrides what is stored")
    func liveOverridesStored() {
        let session = SessionID("a")
        let stored = [SessionActivity(sessionID: session, workspaceID: first, state: .running)]
        let live = [AgentTurns.Live(sessionID: session, workspaceID: first, isRunning: false, isAwaitingPermission: false)]

        let counts = AgentTurns.agentsByWorkspace(
            stored: stored, live: live, runningWorkspaces: [], waitingWorkspaces: []
        )

        #expect(counts.isEmpty)
    }
}
