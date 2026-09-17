import Testing
import Foundation
@testable import Core

@Suite("Revealing something in the window", .tags(.persistence), .scratchDirectory)
struct RevealToolTests {
    @Test("naming no scope shows everything, and the answer says so")
    func noArguments() throws {
        let order = try parse()
        #expect(order == RevealOrder())
        #expect(order.scope == .all)
        let reveal = try resolve(order, workspaces: [], projects: [])
        #expect(reveal.target == .home(HomeFilter(query: "", projects: [], scope: .all)))
        #expect(reveal.sentence == "Unified Dev is on Home, showing All.")
    }

    @Test("a bare reveal leaves nothing out, archived work included")
    func unnamedScopeHidesNothing() {
        #expect(RevealChoice.scopeWhenUnnamed == .all)

        let repo = Repo(name: "unifieddev", path: "/tmp/unifieddev")
        let live = HomeRow(workspace: Workspace(
            repoID: repo.id, name: "Fix the flake", branch: "b1", path: "/p1", baseBranch: "main"
        ))
        let finished = HomeRow(workspace: Workspace(
            repoID: repo.id, name: "Warm the cache", branch: "b2", path: "/p2",
            baseBranch: "main", state: .archived
        ))

        let scope = RevealChoice.scopeWhenUnnamed
        #expect(scope.includes(live, activity: HomeActivity()))
        #expect(scope.includes(finished, activity: HomeActivity()))
    }

    @Test("blank strings are the same as nothing at all")
    func blanksAreNothing() throws {
        let order = try parse(workspace: "   ", search: "")
        #expect(order.workspace == nil)
        #expect(order.search.isEmpty)
    }

    @Test("a workspace and a Home narrowing together is refused rather than one winning")
    func refusesBothAtOnce() {
        for extra in [("project", "unifieddev"), ("search", "flake"), ("scope", "running")] {
            var arguments: [String: JSONValue] = ["workspace": .string("Fix the flake")]
            arguments[extra.0] = .string(extra.1)
            let outcome = RevealChoice.parse(
                workspace: arguments["workspace"],
                project: arguments["project"],
                scope: arguments["scope"],
                search: arguments["search"]
            )
            guard case .failure(let refusal) = outcome else {
                Issue.record("expected a refusal for \(extra.0)"); return
            }
            #expect(refusal.sentence.contains("ambiguous"))
        }
    }

    @Test("a scope Home does not have is refused, with the ones it does")
    func unknownScope() {
        guard case .failure(let refusal) = RevealChoice.parse(
            workspace: nil, project: nil, scope: .string("finished"), search: nil
        ) else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("finished"))
        #expect(refusal.sentence.contains("needsYou"))
    }

    @Test("the search-only chips are not on offer")
    func searchOnlyScopesAreNotOffered() {
        #expect(!RevealChoice.offered.contains(.workspaces))
        #expect(!RevealChoice.offered.contains(.transcripts))
        #expect(RevealChoice.offered == [.all, .needsYou, .running, .live, .archived])
    }

    @Test("a workspace is found by name, and by id")
    func findsWorkspace() throws {
        let (workspaces, projects) = world()
        let byName = try resolve(try parse(workspace: "fix the flake"), workspaces: workspaces, projects: projects)
        #expect(byName.target == .workspace(workspaces[0].id))
        #expect(byName.sentence.contains("Fix the flake"))
        #expect(byName.sentence.contains("unifieddev"))

        let byID = try resolve(
            try parse(workspace: workspaces[1].id.rawValue), workspaces: workspaces, projects: projects
        )
        #expect(byID.target == .workspace(workspaces[1].id))
    }

    @Test("a name nothing answers to is refused with the names there are")
    func refusesUnknownWorkspace() throws {
        let (workspaces, projects) = world()
        guard case .failure(let refusal) = RevealChoice.resolve(
            try parse(workspace: "Ship it"), workspaces: workspaces, projects: projects
        ) else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("Ship it"))
        #expect(refusal.sentence.contains("Fix the flake"))
    }

    @Test("two workspaces with one name is refused, and asks for the id")
    func refusesAmbiguousWorkspace() throws {
        var (workspaces, projects) = world()
        workspaces.append(Workspace(
            repoID: projects[1].id, name: "Fix the flake", branch: "b3", path: "/p3", baseBranch: "main"
        ))
        guard case .failure(let refusal) = RevealChoice.resolve(
            try parse(workspace: "Fix the flake"), workspaces: workspaces, projects: projects
        ) else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("2 workspaces"))
        #expect(refusal.sentence.contains("id"))
    }

    @Test("a refusal stops listing before it becomes a directory")
    func refusalListIsCapped() {
        let names = (1...25).map { "workspace \($0)" }
        let listed = RevealChoice.list(names)
        #expect(listed.contains("workspace 10"))
        #expect(!listed.contains("workspace 11"))
        #expect(listed.contains("15 more"))
    }

    @Test("a project, a scope and a search become one filter, and one sentence")
    func homeFilter() throws {
        let (workspaces, projects) = world()
        let reveal = try resolve(
            try parse(project: "unifieddev", scope: "archived", search: "parser"),
            workspaces: workspaces,
            projects: projects
        )
        #expect(reveal.target == .home(HomeFilter(
            query: "parser", projects: [projects[0].id], scope: .archived
        )))
        #expect(reveal.sentence.contains("unifieddev"))
        #expect(reveal.sentence.contains("Archived"))
        #expect(reveal.sentence.contains("parser"))
        #expect(try resolve(try parse(), workspaces: [], projects: []).sentence.contains("All"))
    }

    @Test("a project is found by path as well as by name")
    func projectByPath() throws {
        let (workspaces, projects) = world()
        let reveal = try resolve(
            try parse(project: projects[1].path), workspaces: workspaces, projects: projects
        )
        #expect(reveal.target == .home(HomeFilter(
            query: "", projects: [projects[1].id], scope: .all
        )))
        #expect(reveal.sentence.contains("mailcoach"))
    }

    @Test("a project nothing answers to is refused with the projects there are")
    func refusesUnknownProject() throws {
        let (workspaces, projects) = world()
        guard case .failure(let refusal) = RevealChoice.resolve(
            try parse(project: "ember"), workspaces: workspaces, projects: projects
        ) else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("ember"))
        #expect(refusal.sentence.contains("mailcoach"))
    }

    @Test("it is the owner's tool and nobody else's")
    func ownerOnly() {
        #expect(RevealTool { _ in .refused("no") }.roles == [.owner])
    }

    @Test("Unified Dev answers its own question for it")
    func selfApproved() {
        #expect(BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + "reveal"))
        #expect(!BridgeToolApproval.selfApproved.contains("workspace_merge"))
        #expect(!BridgeToolApproval.selfApproved.contains("project_add"))
    }

    @Test("it hands the window an id and a sentence, and answers with the sentence")
    func callsThrough() async throws {
        let store = try makeTestStore("reveal")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: "/tmp/unifieddev"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Fix the flake", branch: "b", path: "/p", baseBranch: "main"
        ))

        let recorder = Recorder()
        let tool = RevealTool { reveal in
            await recorder.record(reveal)
            return .revealed(reveal.sentence)
        }
        let result = await tool.call(
            MCPRequest(
                id: .integer(1),
                method: "reveal",
                params: .object(["workspace": .string("Fix the flake")])
            ),
            as: .owner,
            store: store
        )

        #expect(!result.isError)
        #expect(result.text.contains("Fix the flake"))
        #expect(await recorder.reveals.map(\.target) == [.workspace(workspace.id)])
    }

    @Test("a window that is not there yet refuses rather than pretending")
    func refusesWhenTheWindowIsNotThere() async throws {
        let store = try makeTestStore("reveal-no-window")
        let tool = RevealTool { _ in .refused("Unified Dev is still starting up.") }
        let result = await tool.call(
            MCPRequest(id: .integer(1), method: "reveal", params: .object([:])),
            as: .owner,
            store: store
        )
        #expect(result.isError)
        #expect(result.text == "Unified Dev is still starting up.")
    }

    private func parse(
        workspace: String? = nil,
        project: String? = nil,
        scope: String? = nil,
        search: String? = nil
    ) throws -> RevealOrder {
        let outcome = RevealChoice.parse(
            workspace: workspace.map { .string($0) },
            project: project.map { .string($0) },
            scope: scope.map { .string($0) },
            search: search.map { .string($0) }
        )
        guard case .success(let order) = outcome else {
            throw RevealTestTrouble.refused
        }
        return order
    }

    private func resolve(
        _ order: RevealOrder,
        workspaces: [Workspace],
        projects: [Repo]
    ) throws -> RevealPlan {
        guard case .success(let reveal) = RevealChoice.resolve(
            order, workspaces: workspaces, projects: projects
        ) else {
            throw RevealTestTrouble.refused
        }
        return reveal
    }

    private func world() -> ([Workspace], [Repo]) {
        let unifieddev = Repo(name: "unifieddev", path: "/tmp/unifieddev")
        let mailcoach = Repo(name: "mailcoach", path: "/tmp/mailcoach")
        return (
            [
                Workspace(
                    repoID: unifieddev.id, name: "Fix the flake", branch: "b1", path: "/p1",
                    baseBranch: "main"
                ),
                Workspace(
                    repoID: mailcoach.id, name: "Warm the cache", branch: "b2", path: "/p2",
                    baseBranch: "main"
                ),
            ],
            [unifieddev, mailcoach]
        )
    }

    private enum RevealTestTrouble: Error { case refused }

    private actor Recorder {
        var reveals: [RevealPlan] = []

        func record(_ reveal: RevealPlan) { reveals.append(reveal) }
    }
}
