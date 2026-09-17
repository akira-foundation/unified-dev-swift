import Testing
import Foundation
@testable import Core

@Suite("Carrying an archived conversation on")
struct CarryOnGateTests {
    private func facts(
        branch: String = "dark-mode-toggle",
        base: String = "main",
        defaultBranch: String = "main",
        branches: [String] = ["main", "develop"],
        source: RestoreSource? = .gone,
        thread: String? = "28e661ae-649a-4fa4-97c8-86fd66d72cc3",
        kind: AgentKind = .claudeCode
    ) -> CarryOnFacts {
        CarryOnFacts(
            branch: branch,
            baseBranch: base,
            defaultBranch: defaultBranch,
            branches: branches,
            restoreSource: source,
            agentSessionID: thread,
            agentKind: kind
        )
    }

    @Test("a merged workspace whose branch is gone is carried on, on the next branch along")
    func offered() {
        let plan = CarryOnGate.decide(facts()).plan
        #expect(plan?.branch == "dark-mode-toggle-2")
        #expect(plan?.baseBranch == "main")
        #expect(plan?.agentSessionID == "28e661ae-649a-4fa4-97c8-86fd66d72cc3")
    }

    @Test("nothing is offered while the branch is still being looked for")
    func stillLooking() {
        #expect(CarryOnGate.decide(facts(source: nil)).refusal == .stillLooking)
    }

    @Test("a workspace that can be restored is not offered a lossier way back")
    func restorable() {
        #expect(CarryOnGate.decide(facts(source: .localBranch)).refusal == .canBeRestored)
        #expect(
            CarryOnGate.decide(facts(source: .remoteBranch(ref: "refs/remotes/origin/x")))
                .refusal == .canBeRestored
        )
    }

    @Test("a chat no agent ever ran in has no thread to resume")
    func neverRan() {
        #expect(CarryOnGate.decide(facts(thread: nil)).refusal == .neverRan)
        #expect(CarryOnGate.decide(facts(thread: "")).refusal == .neverRan)
        #expect(CarryOnGate.decide(facts(thread: "   ")).refusal == .neverRan)
    }

    @Test("a backend Unified Dev has no runner for cannot pick a thread up")
    func backend() {
        #expect(
            CarryOnGate.decide(facts(kind: .cursor)).refusal == .backendCannotResume(.cursor)
        )
        #expect(CarryOnGate.decide(facts(kind: .codex)).plan?.agentKind == .codex)
    }

    @Test("the plan carries the chat's own backend, so the thread goes back to the CLI that has it")
    func backendTravels() {
        #expect(CarryOnGate.decide(facts(kind: .claudeCode)).plan?.agentKind == .claudeCode)
    }

    @Test("a base branch that has itself been deleted since falls back to the project's default")
    func staleBase() {
        let plan = CarryOnGate.decide(
            facts(base: "release-3", defaultBranch: "main", branches: ["main", "develop"])
        ).plan
        #expect(plan?.baseBranch == "main")
    }

    @Test("a base branch that is still there is used, default branch or not")
    func liveBase() {
        let plan = CarryOnGate.decide(
            facts(base: "develop", defaultBranch: "main", branches: ["main", "develop"])
        ).plan
        #expect(plan?.baseBranch == "develop")
    }

    @Test("the archived branch's own name is not reused, free though it is")
    func neverTheOldName() {
        let plan = CarryOnGate.decide(facts(branches: ["main"])).plan
        #expect(plan?.branch == "dark-mode-toggle-2")
    }

    @Test("the new branch avoids every branch the repository already has")
    func avoidsTakenBranches() {
        let plan = CarryOnGate.decide(
            facts(branches: ["main", "dark-mode-toggle-2", "dark-mode-toggle-3"])
        ).plan
        #expect(plan?.branch == "dark-mode-toggle-4")
    }

    @Test("a branch prefix comes along, because the whole name is carried rather than rebuilt")
    func keepsPrefix() {
        let plan = CarryOnGate.decide(facts(branch: "freek/dark-mode-toggle")).plan
        #expect(plan?.branch == "freek/dark-mode-toggle-2")
    }

    @Test("a name git would not accept is refused rather than handed to git")
    func invalidName() {
        #expect(CarryOnGate.decide(facts(branch: "has a space")).refusal == .noValidName)
    }

    @Test("the refusals are ordered so the reader's actual state is the one that decides")
    func order() {
        #expect(
            CarryOnGate.decide(facts(source: nil, thread: nil, kind: .cursor)).refusal
                == .stillLooking
        )
        #expect(
            CarryOnGate.decide(facts(source: .localBranch, thread: nil)).refusal == .canBeRestored
        )
    }
}

@Suite("The turn that hands an archive over")
struct ArchivedCarryOnTests {
    private let handover = ArchivedCarryOn(
        name: "Dark mode toggle",
        project: "Unified Dev",
        previousBranch: "freek/dark-mode-toggle",
        previousPath: "/Users/freek/unifieddev-workspaces/unifieddev/dark-mode-toggle",
        branch: "freek/dark-mode-toggle-2",
        baseBranch: "main"
    )

    @Test("every variable the registry offers is filled in")
    func everyVariable() {
        let values = handover.promptValues()
        let declared = PromptRegistry.definition(for: .carryOnArchived).variables.map(\.name)
        #expect(Set(declared) == Set(values.keys))
    }

    @Test("the default template names the archive, the branch it lost and the branch it is on now")
    func rendersTheDefault() {
        let render = handover.render(
            template: PromptRegistry.definition(for: .carryOnArchived).defaultTemplate
        )
        #expect(render.text.contains("Dark mode toggle"))
        #expect(render.text.contains("freek/dark-mode-toggle-2"))
        #expect(render.text.contains("/Users/freek/unifieddev-workspaces/unifieddev/dark-mode-toggle"))
        #expect(render.text.contains("main"))
        #expect(render.text.contains("Unified Dev"))
        #expect(!render.text.contains("{{"))
    }

    @Test("the banner sentence says what is on offer without promising the workspace comes back")
    func standingSentence() {
        let sentence = ArchivedCarryOn.standing(project: "Unified Dev", baseBranch: "main")
        #expect(sentence.contains("main"))
        #expect(sentence.contains("Unified Dev"))
        #expect(sentence.contains("This archive is left exactly as it is."))
    }

    @Test("the plan and the archived row are enough to build it")
    func fromAPlan() {
        let workspace = Workspace(
            repoID: RepoID("repo"),
            name: "Dark mode toggle",
            branch: "freek/dark-mode-toggle",
            path: "/Users/freek/unifieddev-workspaces/unifieddev/dark-mode-toggle",
            baseBranch: "main"
        )
        let built = ArchivedCarryOn(
            workspace: workspace,
            project: "Unified Dev",
            plan: CarryOnPlan(
                branch: "freek/dark-mode-toggle-2",
                baseBranch: "main",
                agentSessionID: "thread",
                agentKind: .claudeCode
            )
        )
        #expect(built == handover)
    }
}
