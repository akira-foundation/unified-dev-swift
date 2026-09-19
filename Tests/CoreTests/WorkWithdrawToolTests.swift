import Foundation
import Testing
@testable import Core

@Suite("work_withdraw", .tags(.persistence), .scratchDirectory)
struct WorkWithdrawToolTests {
    private struct Fixture {
        let store: Store
        let workspace: Workspace
        let chat: Session
        let suggestion: WorkSuggestion

        func identity(of chat: Session? = nil) -> BridgeIdentity {
            BridgeIdentity(sessionID: (chat ?? self.chat).id, workspaceID: workspace.id, role: .parent)
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
        let admission = try await store.addWorkSuggestion(WorkSuggestion(
            workspaceID: workspace.id, sessionID: chat.id, title: "Keep the last row",
            why: "The parser drops the last row.", prompt: "Keep the last row.", target: .sameProject
        ))
        return Fixture(store: store, workspace: workspace, chat: chat, suggestion: try #require(admission.suggestion))
    }

    private func withdrawing(_ id: String) -> MCPRequest {
        MCPRequest(id: .number(1), method: WorkWithdrawTool.name, params: .object(["suggestion_id": .string(id)]))
    }

    @Test("a child never sees it, it is Unified Dev's own question, and it needs no app")
    func roleGate() {
        let toolbox = BridgeToolbox(handlers: [WorkWithdrawTool()])

        #expect(toolbox.tools(for: .child).isEmpty)
        #expect(toolbox.tools(for: .parent).map(\.name) == ["work_withdraw"])
        #expect(toolbox.tools(for: .owner).map(\.name) == ["work_withdraw"])
        #expect(BridgeToolbox.standard.handler(named: "work_withdraw", for: .parent) != nil)
        #expect(BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + "work_withdraw"))
    }

    @Test("the chat that made a suggestion withdraws it, and the card says so")
    func withdraws() async throws {
        let f = try await fixture("withdraw")

        let result = await WorkWithdrawTool().call(withdrawing(f.suggestion.id.rawValue), as: f.identity(), store: f.store)
        let read = try await f.store.workSuggestion(id: f.suggestion.id)

        #expect(!result.isError, "\(result.text)")
        #expect(read?.state == .withdrawn)
    }

    @Test("another chat cannot withdraw it")
    func notYours() async throws {
        let f = try await fixture("withdraw-other")
        let other = try await f.store.upsert(Session(workspaceID: f.workspace.id, title: "Review"))

        let result = await WorkWithdrawTool().call(
            withdrawing(f.suggestion.id.rawValue), as: f.identity(of: other), store: f.store
        )
        let read = try await f.store.workSuggestion(id: f.suggestion.id)

        #expect(result.isError)
        #expect(result.text.contains("another chat"))
        #expect(read?.state == .pending)
    }

    @Test("one the owner has started is not withdrawn, and the answer names what it became")
    func startedIsTheOwners() async throws {
        let f = try await fixture("withdraw-started")
        _ = try await f.store.claimWorkSuggestion(id: f.suggestion.id)
        try await f.store.settleWorkSuggestion(
            id: f.suggestion.id, as: .startedWorkspace(WorkspaceID("w-born"), name: "Keep the last row")
        )

        let result = await WorkWithdrawTool().call(withdrawing(f.suggestion.id.rawValue), as: f.identity(), store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("\"Keep the last row\""))
    }

    @Test("withdrawing twice is not an error the second time")
    func twice() async throws {
        let f = try await fixture("withdraw-twice")

        _ = await WorkWithdrawTool().call(withdrawing(f.suggestion.id.rawValue), as: f.identity(), store: f.store)
        let again = await WorkWithdrawTool().call(withdrawing(f.suggestion.id.rawValue), as: f.identity(), store: f.store)

        #expect(!again.isError, "\(again.text)")
        #expect(again.text.contains("already"))
    }

    @Test("an id Unified Dev does not have, or none at all, is refused")
    func refusesWhatIsNotThere() async throws {
        let f = try await fixture("withdraw-unknown")

        let unknown = await WorkWithdrawTool().call(withdrawing("nowhere"), as: f.identity(), store: f.store)
        let blank = await WorkWithdrawTool().call(withdrawing("  "), as: f.identity(), store: f.store)

        #expect(unknown.isError)
        #expect(unknown.text.contains("'nowhere'"))
        #expect(blank.isError)
        #expect(blank.text.contains("'suggestion_id'"))
    }
    @Test("the owner's own terminal is refused, because it is not a chat that made a suggestion")
    func refusesTheTerminal() async throws {
        let f = try await fixture("withdraw-terminal")

        let result = await WorkWithdrawTool().call(withdrawing(f.suggestion.id.rawValue), as: .owner, store: f.store)
        let read = try await f.store.workSuggestion(id: f.suggestion.id)

        #expect(result.isError)
        #expect(result.text == WorkSuggestTrouble.noChat(tool: WorkWithdrawTool.name).sentence)
        #expect(result.text.contains("work_withdraw"))
        #expect(read?.state == .pending)
    }

    @Test("a suggestion found waiting again is not called decided, and one starting or dismissed says which")
    func decidedWording() {
        let pending = WorkSuggestTrouble.alreadyDecided(.pending).sentence

        #expect(!pending.contains("any more"))
        #expect(pending.contains("waiting for the owner again"))
        #expect(WorkSuggestTrouble.alreadyDecided(.starting).sentence.contains("starting"))
        #expect(WorkSuggestTrouble.alreadyDecided(.dismissed).sentence.contains("dismissed"))
    }
}
