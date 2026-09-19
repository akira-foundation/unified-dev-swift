import Foundation
import Testing
@testable import Core

@Suite("Starting a suggestion when something has gone", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionLaunchTroubleTests {
    private typealias Seams = WorkSuggestionLaunchSeams
    private typealias Fixture = WorkSuggestionLaunchFixture

    private func refusal(_ outcome: WorkSuggestionLaunch.Outcome) -> String? {
        guard case .refused(let sentence) = outcome else { return nil }
        return sentence
    }

    private func breakWrites(_ f: Fixture, when condition: String) throws {
        let raw = try SQLiteDatabase(path: f.store.path)
        try raw.execute("""
            CREATE TRIGGER refuse_suggestion_write BEFORE UPDATE ON work_suggestions
            WHEN \(condition) BEGIN SELECT RAISE(ABORT, 'disk full'); END
            """)
    }

    private func dropTable(_ table: String, _ f: Fixture) throws {
        let raw = try SQLiteDatabase(path: f.store.path)
        try raw.execute("PRAGMA foreign_keys = OFF;")
        try raw.execute("DROP TABLE \(table);")
    }

    @Test("a press after a launch that died finds the workspace it made, settles as started, and makes no second")
    func alreadyStarted() async throws {
        let f = try await Fixture.make("trouble-already")
        let s = try await f.suggest()
        let order = AgentWorkspaceOrder(
            prompt: WorkSuggestionBrief.task(from: s.prompt), name: WorkspaceName.given(s.title)
        )
        let made = try await f.store.upsert(Workspace(
            repoID: f.repo.id, name: "Keep the last row", branch: "claude/keep-the-last-row",
            path: "/tmp/keep-the-last-row", baseBranch: "main",
            origin: .agent(parentWorkspaceID: f.workspace.id, spawnToolUseID: order.spawnID(suggestion: s.id))
        ))
        _ = try await f.store.claimWorkSuggestion(id: s.id)
        _ = try await f.store.releaseWorkSuggestionClaims()
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(outcome.startedSuggestion?.state == .startedWorkspace(made.id, name: made.name), "\(outcome)")
        #expect(seams.orders.isEmpty)
        #expect(try await f.store.workspaces(repoID: f.repo.id).count == 2)
    }

    @Test("a project removed since the suggestion was made is refused, and the card waits again saying so")
    func projectGone() async throws {
        let f = try await Fixture.make("trouble-project")
        let almanac = try await f.store.upsert(Repo(name: "almanac", path: "/tmp/almanac", defaultBranch: "main"))
        let s = try await f.suggest(target: .project(almanac.id))
        try await f.store.deleteRepo(id: almanac.id)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(refusal(outcome)?.contains("That project is no longer in Unified Dev") == true, "\(outcome)")
        #expect(read?.state == .pending)
        #expect(read?.failure == refusal(outcome))
        #expect(seams.orders.isEmpty)
    }

    @Test("work in the chat's own project with no workspace to find it through is refused")
    func workspaceGone() async throws {
        let f = try await Fixture.make("trouble-workspace")
        let ask = try await f.store.upsert(Session(workspaceID: nil, title: "Ask"))
        let s = try await f.suggest(target: .sameProject, from: ask)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(refusal(outcome) == "The workspace this suggestion came from is no longer in Unified Dev.")
        #expect(seams.orders.isEmpty)
    }

    @Test("a chat closed since it suggested the work takes the suggestion with it, and a press is told it has gone")
    func chatGone() async throws {
        let f = try await Fixture.make("trouble-chat")
        let other = try await f.store.upsert(Session(workspaceID: f.workspace.id, title: "Review"))
        let s = try await f.suggest(from: other)
        try await f.store.deleteSession(id: other.id)
        let seams = Seams(store: f.store)

        let here = await seams.launch().launch(s.id, as: .here, store: f.store)
        let new = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(here == .refused(WorkSuggestionWording.gone))
        #expect(new == .refused(WorkSuggestionWording.gone))
        #expect(seams.crewOrders.isEmpty)
        #expect(seams.orders.isEmpty)
    }

    @Test("a claim the database refuses says it could not read the suggestion, and why")
    func claimFails() async throws {
        let f = try await Fixture.make("trouble-claim")
        let s = try await f.suggest()
        try breakWrites(f, when: "NEW.state = 'starting'")
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)

        #expect(refusal(outcome)?.hasPrefix("Unified Dev could not read this suggestion:") == true, "\(outcome)")
        #expect(refusal(outcome)?.contains("Disk full") == true, "\(outcome)")
        #expect(seams.orders.isEmpty)
    }

    @Test("a start that ran but could not be recorded says so, and does not start it twice")
    func settleFails() async throws {
        let f = try await Fixture.make("trouble-settle")
        let s = try await f.suggest()
        try breakWrites(f, when: "NEW.state LIKE 'started%'")
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let again = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(refusal(outcome)?.hasPrefix("Unified Dev could not record what became of this suggestion:") == true)
        #expect(refusal(outcome)?.contains("Disk full") == true, "\(outcome)")
        #expect(read?.state == .starting)
        #expect(again == .refused(WorkSuggestionWording.taken(.starting)))
        #expect(seams.orders.count == 1)
    }

    @Test("a refusal that cannot be written back says so, and the claim is left for the next launch to release")
    func releaseFails() async throws {
        let f = try await Fixture.make("trouble-release")
        let s = try await f.suggest(target: .remote("octo/parsekit"))
        try breakWrites(f, when: "NEW.state = 'pending'")
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(refusal(outcome)?.hasPrefix("Unified Dev could not record what became of this suggestion:") == true)
        #expect(read?.state == .starting)
    }

    @Test("projects that cannot be read are refused with the reason, and the card waits again")
    func projectsUnreadable() async throws {
        let f = try await Fixture.make("trouble-repos")
        let s = try await f.suggest()
        try dropTable("repos", f)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.workSuggestion(id: s.id)

        #expect(refusal(outcome)?.hasPrefix("Unified Dev could not read its projects:") == true, "\(outcome)")
        #expect(read?.state == .pending)
        #expect(seams.orders.isEmpty)
    }

    @Test("chats that cannot be read are refused for Here with the reason")
    func chatsUnreadable() async throws {
        let f = try await Fixture.make("trouble-sessions")
        let s = try await f.suggest()
        try dropTable("sessions", f)
        let seams = Seams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .here, store: f.store)

        #expect(refusal(outcome)?.hasPrefix("Unified Dev could not read this workspace's chats:") == true, "\(outcome)")
        #expect(seams.crewOrders.isEmpty)
    }
}
