import Foundation
import Testing
@testable import Core

@Suite("work_suggest", .tags(.persistence), .scratchDirectory)
struct WorkSuggestToolTests {
    private struct Fixture {
        let store: Store
        let repo: Repo
        let workspace: Workspace
        let chat: Session

        var identity: BridgeIdentity {
            BridgeIdentity(sessionID: chat.id, workspaceID: workspace.id, role: .parent)
        }
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

    private func suggesting(_ extra: [String: JSONValue] = [:]) -> MCPRequest {
        var arguments: [String: JSONValue] = [
            "title": .string("Keep the last row"),
            "why": .string("The parser drops the last row of every file."),
            "prompt": .string("Make the parser keep the last row, with a test that fails without the fix."),
        ]
        arguments.merge(extra) { _, new in new }
        return MCPRequest(id: .number(1), method: WorkSuggestTool.name, params: .object(arguments))
    }

    @Test("a child never sees it; a workspace agent and the owner's clients do")
    func roleGate() {
        let toolbox = BridgeToolbox(handlers: [WorkSuggestTool()])

        #expect(toolbox.tools(for: .child).isEmpty)
        #expect(toolbox.tools(for: .parent).map(\.name) == ["work_suggest"])
        #expect(toolbox.tools(for: .owner).map(\.name) == ["work_suggest"])
        #expect(BridgeToolbox.standard.handler(named: "work_suggest", for: .parent) != nil)
    }

    @Test("Unified Dev answers its permission question, because suggesting starts nothing")
    func selfApproved() {
        #expect(BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + "work_suggest"))
    }

    @Test("a suggestion waits for the owner in the calling chat, and nothing starts")
    func suggests() async throws {
        let f = try await fixture("suggest")

        let result = await WorkSuggestTool().call(suggesting(), as: f.identity, store: f.store)
        let answer = try #require(JSONValue.parse(result.text))
        let id = try #require(answer["suggestion_id"]?.stringValue)
        let stored = try #require(try await f.store.workSuggestion(id: WorkSuggestionID(id)))
        let workspaces = try await f.store.workspaces()

        #expect(!result.isError, "\(result.text)")
        #expect(answer["state"] == .string("waiting_for_the_owner"))
        #expect(stored.state == .pending)
        #expect(stored.target == .sameProject)
        #expect(stored.sessionID == f.chat.id)
        #expect(stored.workspaceID == f.workspace.id)
        #expect(stored.title == "Keep the last row")
        #expect(workspaces.count == 1)
    }

    @Test("a suggestion missing its title, its reason or its prompt is refused, and nothing is written",
          arguments: ["title", "why", "prompt"])
    func refusesWhatIsMissing(field: String) async throws {
        let f = try await fixture("suggest-missing-\(field)")

        let result = await WorkSuggestTool().call(suggesting([field: .string("   ")]), as: f.identity, store: f.store)
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(result.isError)
        #expect(result.text.contains("'\(field)'"))
        #expect(stored.isEmpty)
    }

    @Test("a prompt longer than a card carries is refused")
    func refusesAnOverlongPrompt() async throws {
        let f = try await fixture("suggest-long")
        let long = String(repeating: "a", count: WorkSuggestTool.promptLimit + 1)

        let result = await WorkSuggestTool().call(suggesting(["prompt": .string(long)]), as: f.identity, store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("\(WorkSuggestTool.promptLimit)"))
    }

    @Test("a title written over several lines is kept as one line")
    func titleIsOneLine() async throws {
        let f = try await fixture("suggest-title")

        _ = await WorkSuggestTool().call(
            suggesting(["title": .string("Keep\nthe   last row")]), as: f.identity, store: f.store
        )
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(stored.map(\.title) == ["Keep the last row"])
    }

    @Test("a sixth waiting suggestion is refused, and the refusal says how to make room")
    func refusesTheSixth() async throws {
        let f = try await fixture("suggest-sixth")
        for index in 1...WorkSuggestion.undecidedLimit {
            _ = await WorkSuggestTool().call(
                suggesting(["title": .string("Work \(index)")]), as: f.identity, store: f.store
            )
        }

        let sixth = await WorkSuggestTool().call(suggesting(), as: f.identity, store: f.store)

        #expect(sixth.isError)
        #expect(sixth.text.contains("work_withdraw"))
    }

    @Test("a project Unified Dev has is kept as that project, and naming its own is naming none")
    func namesAProject() async throws {
        let f = try await fixture("suggest-project")
        let almanac = try await f.store.upsert(Repo(name: "almanac", path: "/tmp/almanac", defaultBranch: "main"))

        _ = await WorkSuggestTool().call(suggesting(["project": .string("almanac")]), as: f.identity, store: f.store)
        _ = await WorkSuggestTool().call(
            suggesting(["project": .string("lantern"), "title": .string("Own")]), as: f.identity, store: f.store
        )
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(stored.map(\.target) == [.project(almanac.id), .sameProject])
    }

    @Test("a repository on disk that Unified Dev does not have is kept as its path",
          arguments: ["/tmp/tidewater", "/tmp/tidewater/"])
    func keepsAFolder(given: String) async throws {
        let f = try await fixture("suggest-folder")

        _ = await WorkSuggestTool().call(suggesting(["project": .string(given)]), as: f.identity, store: f.store)
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(stored.map(\.target) == [.folder("/tmp/tidewater")])
    }

    @Test("a path Unified Dev already has is that project, not a folder to add")
    func aKnownPathIsTheProject() async throws {
        let f = try await fixture("suggest-known-path")
        let almanac = try await f.store.upsert(Repo(name: "almanac", path: "/tmp/almanac", defaultBranch: "main"))

        _ = await WorkSuggestTool().call(suggesting(["project": .string("/tmp/almanac/")]), as: f.identity, store: f.store)
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(stored.map(\.target) == [.project(almanac.id)])
    }

    @Test("a repository only on GitHub is kept as owner/repository", arguments: [
        "octo/parsekit",
        "https://github.com/octo/parsekit",
        "https://github.com/octo/parsekit.git",
        "git@github.com:octo/parsekit.git",
    ])
    func keepsARemote(given: String) async throws {
        let f = try await fixture("suggest-remote")

        _ = await WorkSuggestTool().call(suggesting(["project": .string(given)]), as: f.identity, store: f.store)
        let stored = try await f.store.workSuggestions(sessionID: f.chat.id)

        #expect(stored.map(\.target) == [.remote("octo/parsekit")])
    }

    @Test("a name Unified Dev does not know is refused with the names it does")
    func refusesAnUnknownName() async throws {
        let f = try await fixture("suggest-unknown")

        let result = await WorkSuggestTool().call(suggesting(["project": .string("nowhere")]), as: f.identity, store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("'nowhere'"))
        #expect(result.text.contains("'lantern'"))
    }

    @Test("the owner's own terminal is refused, because there is no chat to put a card in")
    func refusesTheTerminal() async throws {
        let f = try await fixture("suggest-terminal")

        let result = await WorkSuggestTool().call(suggesting(["project": .string("lantern")]), as: .owner, store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("Ask Unified Dev"))
    }

    @Test("an Ask chat has to name a project, and may")
    func askNamesAProject() async throws {
        let f = try await fixture("suggest-ask")
        let ask = try await f.store.upsert(Session(workspaceID: nil, title: "Ask"))
        let identity = BridgeIdentity(ownerSession: ask.id)

        let bare = await WorkSuggestTool().call(suggesting(), as: identity, store: f.store)
        let named = await WorkSuggestTool().call(suggesting(["project": .string("lantern")]), as: identity, store: f.store)
        let stored = try await f.store.workSuggestions(sessionID: ask.id)

        #expect(bare.isError)
        #expect(bare.text.contains("'project'"))
        #expect(!named.isError, "\(named.text)")
        #expect(stored.map(\.target) == [.project(f.repo.id)])
        #expect(stored.map(\.workspaceID) == [nil])
    }

    @Test("the description says nothing starts, and when to reach for the other two tools")
    func description() {
        let text = WorkSuggestTool().tool.description

        #expect(text.contains("Nothing starts until"))
        #expect(text.contains("workspace_start"))
        #expect(text.contains("agent_start"))
        #expect(text.contains("work_withdraw"))
    }
}
