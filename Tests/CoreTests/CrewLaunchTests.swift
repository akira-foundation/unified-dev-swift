import Foundation
import Testing
@testable import Core

@Suite("Starting a subagent for an agent or a card", .tags(.persistence), .scratchDirectory)
struct CrewLaunchTests {
    private final class Starts: @unchecked Sendable {
        var orders: [CrewOrder] = []
        var outcome: CrewStartOutcome = .started("Started.")

        var start: CrewStarting {
            { [self] order, _, _ in
                orders.append(order)
                return outcome
            }
        }
    }

    private struct Fixture {
        let store: Store
        let workspace: Workspace
        let orchestrator: Session
    }

    private func fixture(_ label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "lantern", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "crew", branch: "lantern/crew",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let orchestrator = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        return Fixture(store: store, workspace: workspace, orchestrator: orchestrator)
    }

    private func launch(
        _ f: Fixture, name: String = "  tests ", task: String? = "Keep the suite green.",
        from caller: Session? = nil, starts: Starts
    ) async -> CrewLaunchOutcome {
        await CrewLaunch.launch(
            name: name, task: task, model: nil, effort: nil,
            from: caller ?? f.orchestrator, in: f.workspace.id, store: f.store, start: starts.start
        )
    }

    @Test("a launch passes on the accepted name and the task, and says which name it used")
    func launches() async throws {
        let f = try await fixture("crew-launch")
        let starts = Starts()

        let outcome = await launch(f, starts: starts)

        #expect(outcome == .started(sentence: "Started.", name: "tests"))
        #expect(starts.orders == [CrewOrder(name: "tests", task: "Keep the suite green.")])
    }

    @Test("a full workspace is refused by the ceiling rule, and nothing starts")
    func full() async throws {
        let f = try await fixture("crew-launch-full")
        for slot in 1...Crew.ceiling {
            _ = try await f.store.upsert(Session(
                workspaceID: f.workspace.id, parentSessionID: f.orchestrator.id,
                title: "slot-\(slot)", state: .running
            ))
        }
        let starts = Starts()

        let outcome = await launch(f, starts: starts)

        #expect(outcome == .refused(.rule(.tooMany(running: Crew.ceiling))))
        #expect(starts.orders.isEmpty)
    }

    @Test("a subagent cannot launch one")
    func notFromASubagent() async throws {
        let f = try await fixture("crew-launch-depth")
        let member = try await f.store.upsert(Session(
            workspaceID: f.workspace.id, parentSessionID: f.orchestrator.id, title: "reader"
        ))
        let starts = Starts()

        let outcome = await launch(f, from: member, starts: starts)

        #expect(outcome == .refused(.rule(.notAnOrchestrator)))
        #expect(starts.orders.isEmpty)
    }

    @Test("a blank task is refused once the name has been accepted")
    func noTask() async throws {
        let f = try await fixture("crew-launch-task")
        let starts = Starts()

        let outcome = await launch(f, task: "   ", starts: starts)

        #expect(outcome == .refused(.noTask))
        #expect(CrewLaunchRefusal.noTask.sentence == CrewToolTrouble.noTask.sentence)
    }

    @Test("the app's own refusal is passed on as it was written")
    func appRefusal() async throws {
        let f = try await fixture("crew-launch-app")
        let starts = Starts()
        starts.outcome = .refused("That workspace is not open in Unified Dev any more.")

        let outcome = await launch(f, starts: starts)

        #expect(outcome == .refused(.refused("That workspace is not open in Unified Dev any more.")))
    }
}
