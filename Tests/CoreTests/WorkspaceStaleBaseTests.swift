import Foundation
import Testing
@testable import Core

@Suite("A cut whose base could not be fetched", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceStaleBaseTests {
    private func unreachableClone(named name: String) async throws -> (server: TempRepo, work: TempRepo, stale: String) {
        let server = try await TempRepo()
        let work = try await TempRepo.clone(of: server, named: name)
        let stale = try await Git.headSHA(of: work.path)
        try server.write("landed.md", "merged after the remote went quiet\n")
        try await server.commit("land something")
        try await Shell.check("git", ["remote", "set-url", "origin", server.path + "-gone"], cwd: work.path)
        return (server, work, stale)
    }

    @Test("the cut stops and says so rather than starting from a remote ref it could not refresh")
    func refusesAStaleBase() async throws {
        let (server, work, _) = try await unreachableClone(named: "quiet-remote")
        defer { server.cleanUp(); work.cleanUp() }

        let manager = WorkspaceManager(store: try makeTestStore("stale-refused"))
        let registered = try await manager.addRepository(at: work.path)

        await #expect(throws: BaseNotFetched(branch: registered.defaultBranch, remote: "origin")) {
            try await manager.createWorkspace(repo: registered, prompt: "Next", acceptsStaleBase: false)
        }
        #expect(try await manager.store.workspaces(repoID: registered.id).isEmpty)
    }

    @Test("once the owner accepts it, the cut starts from the remote ref as this Mac last saw it")
    func acceptedStaleBaseCuts() async throws {
        let (server, work, stale) = try await unreachableClone(named: "quiet-remote-accepted")
        defer { server.cleanUp(); work.cleanUp() }

        let manager = WorkspaceManager(store: try makeTestStore("stale-accepted"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Next", acceptsStaleBase: true)

        #expect(try await Git.headSHA(of: workspace.path) == stale)
    }

    @Test("the refusal reaches the caller through a workspace start, which is how the draft asks")
    func startCarriesTheRefusal() async throws {
        let (server, work, _) = try await unreachableClone(named: "quiet-remote-start")
        defer { server.cleanUp(); work.cleanUp() }

        let manager = WorkspaceManager(store: try makeTestStore("stale-start"))
        let registered = try await manager.addRepository(at: work.path)

        await #expect(throws: BaseNotFetched.self) {
            try await manager.start(WorkspaceStartRequest(
                repo: registered, prompt: "Next", origin: .user, opensSession: false,
                setupPolicy: .skip, acceptsStaleBase: false
            ))
        }
    }

    @Test("the second Return fetches again, and a remote that answers by then gives its new head")
    func acceptedStaleBaseStillFetches() async throws {
        let (server, work, _) = try await unreachableClone(named: "quiet-remote-back")
        defer { server.cleanUp(); work.cleanUp() }
        let current = try await Git.headSHA(of: server.path)

        let manager = WorkspaceManager(store: try makeTestStore("stale-back"))
        let registered = try await manager.addRepository(at: work.path)
        await #expect(throws: BaseNotFetched.self) {
            try await manager.createWorkspace(repo: registered, prompt: "First", acceptsStaleBase: false)
        }

        try await Shell.check("git", ["remote", "set-url", "origin", server.path], cwd: work.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Second", acceptsStaleBase: true)

        #expect(try await Git.headSHA(of: workspace.path) == current)
    }

    @Test("the refusal becomes the owner's sentence, marked as a warning a second Return answers")
    func troubleCarriesTheWarning() async {
        let refusal = BaseNotFetched(branch: "main", remote: "origin")
        let trouble = await WorkspaceTrouble.creating(
            refusal, project: "harbour", projectPath: "/nowhere", baseBranch: "main"
        )

        #expect(trouble == .baseNotFetched(refusal))
        #expect(trouble.warnsOfStaleBase)
        #expect(trouble.sentence.contains("could not fetch 'main' from origin"))
        #expect(trouble.sentence.contains("Nothing has been created"))
        #expect(trouble.sentence.contains("'origin/main'"))
        #expect(!WorkspaceTrouble.unexplained("x").warnsOfStaleBase)
    }
}
