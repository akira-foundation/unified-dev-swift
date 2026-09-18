import Foundation
import Testing
@testable import Core

@Suite("Menu bar panel content")
struct MenuBarPanelContentTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func workspace(_ name: String, unread: Bool = false) -> Workspace {
        Workspace(
            repoID: RepoID("repo"),
            name: name,
            branch: "feature/\(name)",
            path: "/tmp/\(name)",
            baseBranch: "main",
            setupState: .succeeded,
            unread: unread
        )
    }

    private func quota(
        _ provider: AgentKind,
        _ window: QuotaWindow,
        _ fraction: Double?,
        resetsIn seconds: TimeInterval? = 86_400
    ) -> AgentQuota {
        AgentQuota(
            provider: provider,
            window: window,
            measure: fraction.map { .fraction($0) } ?? .unknown,
            resetsAt: seconds.map { now.addingTimeInterval($0) },
            observedAt: now
        )
    }

    private let codexWeek = QuotaWindow.lasting(604_800, key: "primary")
    private let fable = QuotaWindow(key: "seven_day_model_fable", label: "Week (Fable)", duration: 604_800)

    private var calmCodex: AgentQuota { quota(.codex, codexWeek, 0.2) }

    private func input(
        workspaces: [Workspace] = [],
        running: [Workspace] = [],
        waiting: [Workspace] = [],
        runningAgents: Int? = nil,
        quotas: [AgentQuota] = [],
        accounts: [AgentKind: AgentAccount] = [:],
        unanswered: Set<AgentKind> = [],
        layout: UsageLayout = UsageLayout(),
        hold: KeepAwake.Hold = .none
    ) -> MenuBarPanelContent.Input {
        MenuBarPanelContent.Input(
            workspaces: workspaces,
            running: Set(running.map(\.id)),
            waiting: Set(waiting.map(\.id)),
            runningAgents: runningAgents ?? running.count,
            quotas: quotas,
            accounts: accounts,
            unanswered: unanswered,
            layout: layout,
            hold: hold,
            now: now
        )
    }

    @Test("with nothing going on it says so, and shows no icons")
    func idle() {
        let content = MenuBarPanelContent.make(input(quotas: [calmCodex]))
        #expect(content.sentence == "No agents running.")
        #expect(content.badges.isEmpty)
        #expect(!content.needsSetup)
    }

    @Test("counts agents and the workspaces they run in")
    func running() {
        let a = workspace("a"), b = workspace("b"), c = workspace("c")
        let content = MenuBarPanelContent.make(input(
            workspaces: [a, b, c], running: [a, b], runningAgents: 3, quotas: [calmCodex]
        ))
        #expect(content.sentence == "3 agents running in 2 workspaces.")
        #expect(content.badges == [.running])
    }

    @Test("one agent in one workspace reads in the singular")
    func singular() {
        let a = workspace("a")
        let content = MenuBarPanelContent.make(input(workspaces: [a], running: [a], quotas: [calmCodex]))
        #expect(content.sentence == "1 agent running in 1 workspace.")
    }

    @Test("an agent running outside any workspace is counted without naming workspaces")
    func askConversation() {
        let content = MenuBarPanelContent.make(input(runningAgents: 1, quotas: [calmCodex]))
        #expect(content.sentence == "1 agent running.")
        #expect(content.badges == [.running])
    }

    @Test("an agent waiting on the owner is said after the running ones")
    func waiting() {
        let a = workspace("a"), b = workspace("b")
        let content = MenuBarPanelContent.make(input(
            workspaces: [b, a], running: [b], waiting: [a], quotas: [calmCodex]
        ))
        #expect(content.sentence == "1 agent running in 1 workspace. 1 agent waiting on you.")
        #expect(content.badges == [.running, .waiting])
    }

    @Test("the example the owner approved reads word for word")
    func approvedExample() {
        let a = workspace("a"), b = workspace("b")
        let content = MenuBarPanelContent.make(input(
            workspaces: [a, b],
            running: [a, b],
            runningAgents: 3,
            quotas: [quota(.codex, codexWeek, 1, resetsIn: 140_400)],
            hold: .whileAgentsRun
        ))
        #expect(content.sentence == "3 agents running in 2 workspaces. Codex weekly limit reached, "
            + "resets in 1d 15h. The Mac stays awake until they finish.")
        #expect(content.badges == [.running, .limitReached, .awake])
    }

    @Test("a limit named after a model keeps the model's name in capitals")
    func modelLimit() {
        let content = MenuBarPanelContent.make(input(quotas: [quota(.claudeCode, fable, 1, resetsIn: 3600)]))
        #expect(content.sentence == "No agents running. Claude Code Fable limit reached, resets in 1h.")
        #expect(content.notices == [MenuBarPanelContent.LimitNotice(
            provider: .claudeCode, title: "Fable", resetsAt: now.addingTimeInterval(3600)
        )])
    }

    @Test("a spent limit with no reset time says only that it is spent")
    func limitWithoutReset() {
        let content = MenuBarPanelContent.make(input(quotas: [quota(.codex, codexWeek, 1, resetsIn: nil)]))
        #expect(content.sentence == "No agents running. Codex weekly limit reached.")
    }

    @Test("a limit that is nearly gone is not a limit reached")
    func nearlyGone() {
        let content = MenuBarPanelContent.make(input(quotas: [quota(.codex, codexWeek, 0.95)]))
        #expect(content.notices.isEmpty)
        #expect(!content.badges.contains(.limitReached))
    }

    @Test("says how long the Mac stays awake, whatever holds it", arguments: [
        (KeepAwake.Hold.indefinitely, "The Mac stays awake until you turn Keep Awake off."),
        (KeepAwake.Hold.until(Date(timeIntervalSince1970: 1_800_003_600)), "The Mac stays awake for 1h more."),
    ])
    func awake(hold: KeepAwake.Hold, phrase: String) {
        let content = MenuBarPanelContent.make(input(quotas: [calmCodex], hold: hold))
        #expect(content.sentence == "No agents running. " + phrase)
        #expect(content.badges == [.awake])
    }

    @Test("with no provider signed in it says how to start")
    func setup() {
        let content = MenuBarPanelContent.make(input())
        #expect(content.needsSetup)
        #expect(content.providers.isEmpty)
        #expect(content.sentence == "No agents running. " + MenuBarPanelContent.setupSentence)
    }

    @Test("a provider shows once it has answered, in the order the owner chose")
    func providers() {
        let account = AgentAccount(provider: .claudeCode, plan: "Max", observedAt: now)
        let layout = UsageLayout(providerOrder: [.codex, .claudeCode])
        let content = MenuBarPanelContent.make(input(
            quotas: [calmCodex], accounts: [.claudeCode: account], layout: layout
        ))
        #expect(content.providers.map(\.kind) == [.codex, .claudeCode])
        #expect(content.providers.allSatisfy { $0.reading == .measured })
    }

    @Test("a provider switched off in Menu Bar settings stays out of the panel")
    func disabledProvider() {
        let layout = UsageLayout(disabledProviders: [.codex])
        let content = MenuBarPanelContent.make(input(quotas: [calmCodex], layout: layout))
        #expect(content.providers.isEmpty)
    }

    @Test("a provider that did not answer the last ask shows no figures")
    func unanswered() {
        let content = MenuBarPanelContent.make(input(quotas: [calmCodex], unanswered: [.codex, .claudeCode]))
        #expect(content.providers == [MenuBarPanelContent.Provider(kind: .codex, reading: .unavailable)])
    }

    @Test("a reading whose window has already reset does not make a provider known")
    func expiredReading() {
        let content = MenuBarPanelContent.make(input(quotas: [quota(.codex, codexWeek, 0.3, resetsIn: -60)]))
        #expect(content.providers.isEmpty)
    }

    @Test("lists waiting agents first, leaves finished ones out, and stops at five")
    func agents() {
        let names = ["r1", "r2", "r3", "r4", "r5"]
        let running = names.map { workspace($0) }
        let asking = workspace("asking")
        let finished = workspace("finished", unread: true)
        let content = MenuBarPanelContent.make(input(
            workspaces: running + [finished, asking], running: running, waiting: [asking], quotas: [calmCodex]
        ))
        #expect(content.agents.map(\.workspace.name) == ["asking", "r1", "r2", "r3", "r4"])
        #expect(content.agents.first?.isWaiting == true)
        #expect(content.moreAgents == 1)
        #expect(MenuBarPanelContent.moreTitle(content.moreAgents) == "+1 more")
    }

    @Test("an agent row carries the glyph and the word the old menu used")
    func agentRow() {
        let row = MenuBarPanelContent.Agent(workspace: workspace("a"), isWaiting: true)
        #expect(row.symbolName == MenuBarSummary.waitingSymbol)
        #expect(row.label == MenuBarSummary.waitingHeading)
        #expect(MenuBarPanelContent.Agent(workspace: workspace("b"), isWaiting: false).label == MenuBarSummary.runningHeading)
    }

    @Test("a provider with no reading says so in a short line")
    func unavailableLine() {
        #expect(MenuBarPanelContent.unavailableLine(for: .codex) == "Codex did not report its limits.")
    }
}
