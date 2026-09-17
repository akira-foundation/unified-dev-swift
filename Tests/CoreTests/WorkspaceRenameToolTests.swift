import Foundation
import Testing
@testable import Core

@Suite("workspace_rename", .tags(.persistence), .scratchDirectory)
struct WorkspaceRenameToolTests {
    private func request(_ arguments: [String: JSONValue] = [:]) -> MCPRequest {
        MCPRequest(id: .number(1), method: "workspace_rename", params: .object(arguments))
    }

    private func answer(_ result: BridgeToolResult) throws -> JSONValue {
        try #require(JSONValue.parse(result.text))
    }

    private func seed(_ store: Store, named name: String = "test") async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: "unifieddev/redesign",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
    }

    private func parent(_ workspace: Workspace) -> BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s-1"), workspaceID: workspace.id, role: .parent)
    }

    @Test("a parent and the owner may call it, a child may not")
    func roleGate() {
        let toolbox = BridgeToolbox(handlers: [WorkspaceRenameTool()])

        #expect(WorkspaceRenameTool().roles == [.parent, .owner])
        #expect(toolbox.tools(for: .parent).map(\.name) == ["workspace_rename"])
        #expect(toolbox.tools(for: .owner).map(\.name) == ["workspace_rename"])
        #expect(toolbox.tools(for: .child).isEmpty)
        #expect(toolbox.handler(named: "workspace_rename", for: .child) == nil)
    }

    @Test("it is served by a Unified Dev with no app behind it, because a name is one column of one row")
    func isInTheStandardToolbox() {
        let names = BridgeToolbox.standard.tools(for: .parent).map(\.name)
        #expect(names.contains("workspace_rename"))
        #expect(BridgeToolbox.standard.tools(for: .owner).map(\.name).contains("workspace_rename"))
        #expect(BridgeToolbox.standard.tools(for: .child).map(\.name) == ["whoami"])
    }

    @Test("Unified Dev answers its own permission question about it")
    func selfApproved() {
        #expect(BridgeToolApproval.isSelfApproved(
            toolName: "\(BridgeToolApproval.toolPrefix)workspace_rename"
        ))
        #expect(BridgeToolApproval.selfApproved.contains("pane_rename"))
        #expect(!BridgeToolApproval.selfApproved.contains("quick_prompt_update"))
    }

    @Test("a name is trimmed, and blank is nothing, exactly as workspace_start reads one")
    func theNameRule() {
        #expect(WorkspaceName.given("  App redesign  ") == "App redesign")
        #expect(WorkspaceName.given("App redesign") == "App redesign")
        #expect(WorkspaceName.given(nil) == nil)
        #expect(WorkspaceName.given("") == nil)
        #expect(WorkspaceName.given("   \n\t ") == nil)
    }

    @Test("a blank name is refused with a sentence rather than quietly ignored")
    func blankNameIsRefused() async throws {
        let store = try makeTestStore("rename-blank")
        let workspace = try await seed(store)

        for blank in ["", "   ", "\n"] {
            let result = await WorkspaceRenameTool().call(
                request(["name": .string(blank)]), as: parent(workspace), store: store
            )
            #expect(result.isError)
            #expect(result.text.contains("cannot be blank"))
        }

        let missing = await WorkspaceRenameTool().call(
            request([:]), as: parent(workspace), store: store
        )
        #expect(missing.isError)

        #expect(try await store.workspace(id: workspace.id)?.name == "test")
    }

    @Test("the name is stored trimmed")
    func storedTrimmed() async throws {
        let store = try makeTestStore("rename-trim")
        let workspace = try await seed(store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("  App redesign\n")]), as: parent(workspace), store: store
        )

        #expect(!result.isError)
        #expect(try await store.workspace(id: workspace.id)?.name == "App redesign")
    }

    @Test("a parent renames the workspace its token speaks for")
    func parentRenamesItsOwn() async throws {
        let store = try makeTestStore("rename-own")
        let workspace = try await seed(store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: parent(workspace), store: store
        )

        #expect(!result.isError)
        #expect(try await store.workspace(id: workspace.id)?.name == "App redesign")

        let json = try answer(result)
        #expect(json["name"]?.stringValue == "App redesign")
        #expect(json["previous_name"]?.stringValue == "test")
        #expect(json["workspace_id"]?.stringValue == workspace.id.rawValue)
        #expect(json["renamed"]?.boolValue == true)
        #expect(json["branch"]?.stringValue == "unifieddev/redesign")
    }

    @Test("a parent naming a workspace is refused rather than having the argument ignored")
    func parentMayNotNameOne() async throws {
        let store = try makeTestStore("rename-named")
        let mine = try await seed(store)
        let theirs = try await store.upsert(Workspace(
            repoID: mine.repoID, name: "somebody else", branch: "b2",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("somebody else")]),
            as: parent(mine), store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("takes no 'workspace' argument"))
        #expect(try await store.workspace(id: mine.id)?.name == "test")
        #expect(try await store.workspace(id: theirs.id)?.name == "somebody else")
    }

    @Test("a token whose workspace is no longer in Unified Dev is told that, not told to try again")
    func parentWhoseRowHasGone() async throws {
        let store = try makeTestStore("rename-nowhere")
        _ = try await seed(store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]),
            as: BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("gone"), role: .parent),
            store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("no longer in Unified Dev"))
    }

    @Test("the owner must say which, because it is sitting in none")
    func ownerMustName() async throws {
        let store = try makeTestStore("rename-unnamed")
        _ = try await seed(store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: .owner, store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("not sitting in one"))
    }

    @Test("the owner names one by its name, or by its id in any case")
    func ownerNamesByNameOrID() async throws {
        let store = try makeTestStore("rename-owner")
        let workspace = try await seed(store)

        let byName = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("TEST")]),
            as: .owner, store: store
        )
        #expect(!byName.isError)
        #expect(try await store.workspace(id: workspace.id)?.name == "App redesign")

        let byID = await WorkspaceRenameTool().call(
            request([
                "name": .string("App redesign, second pass"),
                "workspace": .string(workspace.id.rawValue.uppercased()),
            ]),
            as: .owner, store: store
        )
        #expect(!byID.isError)
        #expect(try await store.workspace(id: workspace.id)?.name == "App redesign, second pass")
    }

    @Test("a name nothing answers to is refused with the names there are")
    func unknownName() async throws {
        let store = try makeTestStore("rename-unknown")
        _ = try await seed(store)

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("redesign")]),
            as: .owner, store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("no workspace called 'redesign'"))
        #expect(result.text.contains("test"))
        #expect(result.text.contains("workspace_list"))
    }

    @Test("a name two workspaces share is refused, and neither is touched")
    func ambiguousName() async throws {
        let store = try makeTestStore("rename-ambiguous")
        let first = try await seed(store)
        let second = try await store.upsert(Workspace(
            repoID: first.repoID, name: "test", branch: "b2",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("test")]),
            as: .owner, store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("2 workspaces are called 'test'"))
        #expect(result.text.contains(first.id.rawValue))
        #expect(result.text.contains(second.id.rawValue))
        #expect(try await store.workspace(id: first.id)?.name == "test")
        #expect(try await store.workspace(id: second.id)?.name == "test")
    }

    @Test("an archived workspace can still be renamed")
    func archivedIsStillNameable() async throws {
        let store = try makeTestStore("rename-archived")
        let workspace = try await seed(store)
        try await store.update(workspaceID: workspace.id) { $0.archive() }

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign"), "workspace": .string("test")]),
            as: .owner, store: store
        )

        #expect(!result.isError)
        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.name == "App redesign")
        #expect(stored.state == .archived)
    }

    @Test("the answer carries the previous name, and calling again with it puts the name back")
    func theUndo() async throws {
        let store = try makeTestStore("rename-undo")
        let workspace = try await seed(store)

        let renamed = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: parent(workspace), store: store
        )
        let was = try #require(try answer(renamed)["previous_name"]?.stringValue)
        #expect(renamed.text.contains("call workspace_rename again with 'test'"))

        let undone = await WorkspaceRenameTool().call(
            request(["name": .string(was)]), as: parent(workspace), store: store
        )

        #expect(!undone.isError)
        #expect(try await store.workspace(id: workspace.id)?.name == "test")
    }

    @Test("a name the workspace already has writes nothing and says so")
    func unchangedNameWritesNothing() async throws {
        let store = try makeTestStore("rename-unchanged")
        let workspace = try await seed(store, named: "App redesign")

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: parent(workspace), store: store
        )

        #expect(!result.isError)
        let json = try answer(result)
        #expect(json["renamed"]?.boolValue == false)
        #expect(json["name"]?.stringValue == "App redesign")
        #expect(json["previous_name"]?.stringValue == "App redesign")
        #expect(result.text.contains("nothing was written"))
    }

    @Test("a rename changes the name and no other column")
    func renameIsIsolated() async throws {
        let store = try makeTestStore("rename-isolation")
        let workspace = try await seed(store)

        try await store.updateDiffStat(
            workspaceID: workspace.id, additions: 41, deletions: 7, files: 3
        )
        try await store.touch(workspaceID: workspace.id, unread: true)
        try await store.update(workspaceID: workspace.id) { $0.pinned = true }

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: parent(workspace), store: store
        )
        #expect(!result.isError)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.name == "App redesign")
        #expect(stored.additions == 41)
        #expect(stored.deletions == 7)
        #expect(stored.changedFiles == 3)
        #expect(stored.unread)
        #expect(stored.pinned)
        #expect(stored.branch == "unifieddev/redesign")
        #expect(stored.path == workspace.path)
    }

    @Test("a rename shuts the automatic namer out, the way typing over the row does")
    func automaticNamingCannotOverwriteIt() async throws {
        let store = try makeTestStore("rename-namer")
        let placeholder = "Foxglove"
        let workspace = try await seed(store, named: placeholder)

        #expect(WorkspaceNaming.mayApplyName(current: placeholder, placeholder: placeholder))

        let result = await WorkspaceRenameTool().call(
            request(["name": .string("App redesign")]), as: parent(workspace), store: store
        )
        #expect(!result.isError)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(!WorkspaceNaming.mayApplyName(current: stored.name, placeholder: placeholder))
    }

    @Test("the lookup takes an id in any case, a name in any case, and refuses a shared name")
    func theLookup() {
        let repo = Repo(name: "unifieddev", path: "/tmp/unifieddev")
        let first = Workspace(
            repoID: repo.id, name: "App redesign", branch: "b1", path: "/p1", baseBranch: "main"
        )
        let second = Workspace(
            repoID: repo.id, name: "app redesign", branch: "b2", path: "/p2", baseBranch: "main"
        )
        let other = Workspace(
            repoID: repo.id, name: "Sentry importer", branch: "b3", path: "/p3", baseBranch: "main"
        )

        #expect(BridgeWorkspaceLookup.find(other.id.rawValue, among: [first, other]) == .found(other))
        #expect(
            BridgeWorkspaceLookup.find(other.id.rawValue.uppercased(), among: [first, other])
                == .found(other)
        )
        #expect(BridgeWorkspaceLookup.find("SENTRY IMPORTER", among: [first, other]) == .found(other))
        #expect(BridgeWorkspaceLookup.find("  ", among: [first, other]) == .unknown)
        #expect(BridgeWorkspaceLookup.find("nothing", among: [first, other]) == .unknown)
        #expect(
            BridgeWorkspaceLookup.find("app redesign", among: [first, second, other])
                == .ambiguous([first, second])
        )
    }
}
