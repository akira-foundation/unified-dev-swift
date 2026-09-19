import Foundation
import Testing
@testable import Core

@Suite("Starting a suggestion from its card", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionLaunchTests {
    private final class Seams: @unchecked Sendable {
        let store: Store
        var orders: [AgentWorkspaceOrder] = []
        var projects: [Repo] = []
        var identities: [BridgeIdentity] = []
        var origins: [WorkspaceOrigin] = []
        var crewOrders: [CrewOrder] = []
        var admitted: [String] = []
        var admission: Result<Repo, WorkSuggestionRefusal> = .failure(WorkSuggestionRefusal("No folder was expected."))

        init(store: Store) {
            self.store = store
        }

        func launch() -> WorkSuggestionLaunch {
            WorkSuggestionLaunch(
                start: { [self] order, project, identity, origin in
                    orders.append(order)
                    projects.append(project)
                    identities.append(identity)
                    origins.append(origin)
                    return StartedWorkspaceSummary(
                        workspaceID: WorkspaceID("w-born-\(orders.count)"), name: order.name ?? "Born",
                        branch: "claude/born", path: "/tmp/born"
                    )
                },
                crew: { [self] order, caller, workspace in
                    crewOrders.append(order)
                    _ = try? await store.upsert(Session(workspaceID: workspace, parentSessionID: caller, title: order.name))
                    return .started("Started.")
                },
                admit: { [self] path in
                    admitted.append(path)
                    return admission
                }
            )
        }
    }

    private struct Fixture {
        let store: Store
        let repo: Repo
        let workspace: Workspace
        let chat: Session
    }

    private func fixture(_ label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer",
            path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        return Fixture(store: store, repo: repo, workspace: workspace, chat: chat)
    }

    private func suggest(
        _ f: Fixture, target: WorkSuggestion.Target = .sameProject, from chat: Session? = nil
    ) async throws -> WorkSuggestion {
        let source = chat ?? f.chat
        let admission = try await f.store.addWorkSuggestion(WorkSuggestion(
            workspaceID: source.workspaceID, sessionID: source.id, title: "Keep the last row",
            why: "The parser drops the last row.", prompt: "Make the parser keep the last row.", target: target
        ))
        return try #require(admission.suggestion)
    }

    private func started(_ outcome: WorkSuggestionLaunch.Outcome) -> WorkSuggestion? {
        guard case .started(let suggestion) = outcome else { return nil }
        return suggestion
    }

    @Test("New Workspace starts a child of the workspace that suggested it, with the card's title and prompt")
    func newWorkspaceIsAChild() async throws {
        let f = try await fixture("launch-new")
        let s = try await suggest(f)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        let settled = try #require(started(outcome), "\(outcome)")
        #expect(settled.state == .startedWorkspace(WorkspaceID("w-born-1"), name: "Keep the last row"))
        #expect(seams.projects.map(\.id) == [f.repo.id])
        #expect(seams.origins.first?.parentWorkspaceID == f.workspace.id)
        #expect(seams.origins.first?.spawnToolUseID == seams.orders.first?.spawnID(suggestion: s.id))
        #expect(seams.identities.first?.sessionID == f.chat.id)
        #expect(seams.orders.first?.prompt == s.prompt)
        #expect(seams.orders.first?.name == "Keep the last row")
    }

    @Test("two presses at once start it once")
    func twoPressesStartOnce() async throws {
        let f = try await fixture("launch-twice")
        let s = try await suggest(f)
        let seams = Seams(store: f.store)
        let launch = seams.launch()

        async let first = launch.launch(s.id, as: .newWorkspace, store: f.store)
        async let second = launch.launch(s.id, as: .newWorkspace, store: f.store)
        let outcomes = await [first, second]

        #expect(seams.orders.count == 1)
        #expect(outcomes.compactMap(started).count == 1)
    }

    @Test("a press after the agent withdrew it is refused with 'Withdrawn by the agent', and nothing starts")
    func withdrawnIsRefused() async throws {
        let f = try await fixture("launch-withdrawn")
        let s = try await suggest(f)
        _ = try await f.store.withdrawWorkSuggestion(id: s.id, by: f.chat.id)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome == .refused("Withdrawn by the agent"))
        #expect(seams.orders.isEmpty)
    }

    @Test("a start the brakes refuse goes back to waiting, saying why and when to try again")
    func refusedWaitsAgain() async throws {
        let f = try await fixture("launch-brake")
        for index in 0..<WorkspaceStartAllowance.maximumChildren {
            _ = try await f.store.upsert(Workspace(
                repoID: f.repo.id, name: "child \(index)", branch: "claude/child-\(index)",
                path: "/tmp/child-\(index)", baseBranch: "main",
                origin: .agent(parentWorkspaceID: f.workspace.id, spawnToolUseID: "t\(index)")
            ))
        }
        let s = try await suggest(f)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        guard case .refused(let sentence) = outcome else { Issue.record("\(outcome)"); return }
        #expect(sentence.contains("archived"))
        #expect(read?.state == .pending)
        #expect(read?.failure == sentence)
        #expect(seams.orders.isEmpty)
    }

    @Test("Here starts a subagent of the chat that suggested it, named after the card")
    func hereStartsASubagent() async throws {
        let f = try await fixture("launch-here")
        let s = try await suggest(f)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .here, store: f.store)
        let crew = try await f.store.crew(of: f.chat.id)

        let settled = try #require(started(outcome), "\(outcome)")
        let member = try #require(crew.first)
        #expect(settled.state == .startedHere(member.id, name: "Keep the last row"))
        #expect(seams.crewOrders.map(\.task) == [s.prompt])
        #expect(seams.orders.isEmpty)
    }

    @Test("Here takes the next free name when the title is already a subagent's")
    func hereTakesAFreeName() async throws {
        let f = try await fixture("launch-here-name")
        _ = try await f.store.upsert(Session(
            workspaceID: f.workspace.id, parentSessionID: f.chat.id, title: "Keep the last row"
        ))
        let s = try await suggest(f)
        let seams = Seams(store: f.store)

        _ = await seams.launch().launch(s.id, as: .here, store: f.store)

        #expect(seams.crewOrders.map(\.name) == ["Keep the last row 2"])
    }

    @Test("Here is refused for work in another project, and the card waits again")
    func hereOnlyAtHome() async throws {
        let f = try await fixture("launch-here-elsewhere")
        let almanac = try await f.store.upsert(Repo(name: "almanac", path: "/tmp/almanac", defaultBranch: "main"))
        let s = try await suggest(f, target: .project(almanac.id))
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .here, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(outcome == .refused(WorkSuggestionWording.hereElsewhere))
        #expect(read?.state == .pending)
        #expect(seams.crewOrders.isEmpty)
    }

    @Test("a hidden project comes back into the sidebar when a suggestion starts in it")
    func hiddenComesBack() async throws {
        let f = try await fixture("launch-hidden")
        let almanac = try await f.store.upsert(Repo(name: "almanac", path: "/tmp/almanac", defaultBranch: "main", hidden: true))
        let s = try await suggest(f, target: .project(almanac.id))
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.repo(id: almanac.id)

        #expect(started(outcome) != nil, "\(outcome)")
        #expect(read?.hidden == false)
        #expect(seams.projects.map(\.id) == [almanac.id])
    }

    @Test("a folder passes the Add Project check before anything starts, and starts in what it became")
    func folderIsAdmittedFirst() async throws {
        let f = try await fixture("launch-folder")
        let tidewater = try await f.store.upsert(Repo(name: "tidewater", path: "/tmp/tidewater", defaultBranch: "main"))
        let s = try await suggest(f, target: .folder("/tmp/tidewater"))
        let seams = Seams(store: f.store)
        seams.admission = .success(tidewater)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(started(outcome) != nil, "\(outcome)")
        #expect(seams.admitted == ["/tmp/tidewater"])
        #expect(seams.projects.map(\.id) == [tidewater.id])
    }

    @Test("a folder the Add Project check refuses starts nothing, and the card says why")
    func folderRefused() async throws {
        let f = try await fixture("launch-folder-refused")
        let s = try await suggest(f, target: .folder("/tmp/nowhere"))
        let seams = Seams(store: f.store)
        seams.admission = .failure(WorkSuggestionRefusal("There is nothing at that path any more."))

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(outcome == .refused("There is nothing at that path any more."))
        #expect(read?.failure == "There is nothing at that path any more.")
        #expect(seams.orders.isEmpty)
    }

    @Test("a repository only on GitHub is not started")
    func remoteIsNotStarted() async throws {
        let f = try await fixture("launch-remote")
        let s = try await suggest(f, target: .remote("octo/parsekit"))
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome == .refused(WorkSuggestionWording.cloneFirst("octo/parsekit")))
        #expect(seams.orders.isEmpty)
    }

    @Test("an Ask chat's suggestion starts as the owner's, under the owner's rate")
    func askStartsAsTheOwner() async throws {
        let f = try await fixture("launch-ask")
        let ask = try await f.store.upsert(Session(workspaceID: nil, title: "Ask"))
        let s = try await suggest(f, target: .project(f.repo.id), from: ask)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(started(outcome) != nil, "\(outcome)")
        #expect(seams.origins.first?.isOwnerClient == true)
        #expect(seams.identities.first == BridgeIdentity(ownerSession: ask.id))
    }
}
