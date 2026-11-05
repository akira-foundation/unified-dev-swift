import Foundation
import Testing
@testable import Core

@Suite("Editing a canvas document", .scratchDirectory)
struct CanvasEditToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func request(_ fields: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasEditToolName.edit, params: .object(fields))
    }

    private static let frame = CanvasFrame(
        id: CanvasFrameID("f"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100), revision: 2
    )

    private static func box(revision: Int = 3) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID("b"), frameID: frame.id, revision: revision,
            rect: CanvasRect(x: 0, y: 0, width: 10, height: 10), kind: .shape(CanvasShape(kind: .rectangle))
        )
    }

    private func encoded(_ operation: CanvasOperation) throws -> JSONValue {
        try #require(JSONValue.parse(try JSONEncoder().encode(operation)))
    }

    private func fields(of result: BridgeToolResult) throws -> [String: JSONValue] {
        let json = try #require(canvasAnswerJSON(result.text))
        guard case .object(let fields) = json else {
            Issue.record("not an object: \(result.text)")
            return [:]
        }
        return fields
    }

    private func call(
        _ tool: CanvasEditTool, operations: [JSONValue], store: Store
    ) async -> BridgeToolResult {
        await tool.call(
            request(["path": .string(" c.udcanvas "), "operations": .array(operations)]), as: identity, store: store
        )
    }

    @Test("a list of operations reaches the app decoded, with the path and the workspace")
    func editAppliesAsTheAgent() async throws {
        let store = try makeTestStore("canvas-edit")
        let summary = CanvasChangeSummary(
            frames: [CanvasRevisionEntry(id: CanvasFrameID("f"), revision: 3)],
            elements: [CanvasRevisionEntry(id: CanvasElementID("b"), revision: 4)],
            deletedElements: [CanvasElementID("gone")]
        )
        let operation = CanvasOperation.updateElement(
            CanvasElementID("b"), expectedRevision: 3,
            CanvasElementPatch(rect: CanvasRect(x: 5, y: 5, width: 10, height: 10))
        )
        let tool = CanvasEditTool { path, operations, workspaceID in
            #expect(path == "c.udcanvas")
            #expect(workspaceID == WorkspaceID("w"))
            #expect(operations == [operation])
            return .applied(CanvasAgentEditResult(changes: summary, operationCount: operations.count, disk: .saved))
        }
        let result = await call(tool, operations: [try encoded(operation)], store: store)

        #expect(!result.isError)
        let answer = try fields(of: result)
        #expect(answer["applied"] == .bool(true))
        #expect(answer["operationCount"] == .integer(1))
        #expect(answer["saved"] == .bool(true))
        #expect(answer["document"] == nil)
        guard case .object(let revisions)? = answer["revisions"], case .object(let frames)? = revisions["frames"],
              case .object(let elements)? = revisions["elements"], case .object(let deleted)? = answer["deleted"] else {
            Issue.record("no revisions in \(result.text)")
            return
        }
        #expect(frames["f"] == .integer(3))
        #expect(elements["b"] == .integer(4))
        #expect(deleted["elements"] == .array([.string("gone")]))
    }

    @Test("a change that did not reach the file says so, and one that was replaced is an error")
    func answerSaysWhatHappenedOnDisk() async throws {
        let store = try makeTestStore("canvas-edit-disk")
        let operation = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        func answer(_ disk: CanvasDiskOutcome) async -> BridgeToolResult {
            let tool = CanvasEditTool { _, _, _ in
                .applied(CanvasAgentEditResult(changes: CanvasChangeSummary(), operationCount: 1, disk: disk))
            }
            return await call(tool, operations: [operation], store: store)
        }

        let notSaved = await answer(.notSaved("This canvas is not saved"))
        let replaced = await answer(.replaced)

        #expect(!notSaved.isError)
        #expect(try fields(of: notSaved)["saved"] == .bool(false))
        #expect(notSaved.text.contains("Do not commit"))
        #expect(replaced.isError)
        #expect(try fields(of: replaced)["applied"] == .bool(false))
        #expect(replaced.text.contains("Read the canvas again"))
    }

    @Test("an orchestrator, which has Edit and Write taken away, cannot write a canvas through the bridge either")
    func orchestratorIsRefused() async throws {
        let store = try makeTestStore("canvas-edit-orchestrator")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let lead = try await store.upsert(Workspace(
            repoID: repo.id, name: "lead", branch: "b/lead", path: TestScratch.unique("lead"), baseBranch: "main"
        ))
        try await store.setOrchestrator(true, workspaceID: lead.id)
        let caller = BridgeIdentity(sessionID: SessionID("s"), workspaceID: lead.id, role: .workspace)
        let tool = CanvasEditTool { _, _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let operation = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "operations": .array([operation])]), as: caller, store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("orchestrator"))
        #expect(!result.text.contains("terminal"))
    }

    @Test("a conflict reports the current state and says nothing was applied")
    func conflictReportsCurrentState() async throws {
        let store = try makeTestStore("canvas-edit-conflict")
        let current = Self.box(revision: 9)
        let tool = CanvasEditTool { _, _, _ in
            .conflict([CanvasConflict(target: "b", revision: 9, current: .element(current))])
        }
        let operation = CanvasOperation.deleteElement(CanvasElementID("b"), expectedRevision: 3)
        let result = await call(tool, operations: [try encoded(operation)], store: store)

        #expect(result.isError)
        let answer = try fields(of: result)
        #expect(answer["applied"] == .bool(false))
        guard case .array(let conflicts)? = answer["conflicts"], case .object(let first)? = conflicts.first,
              case .object(let element)? = first["element"] else {
            Issue.record("no conflict in \(result.text)")
            return
        }
        #expect(first["target"] == .string("b"))
        #expect(first["revision"] == .integer(9))
        #expect(element["revision"] == .integer(9))
    }

    @Test("an invalid batch is refused with the app's reason")
    func invalidBatchIsRefused() async throws {
        let store = try makeTestStore("canvas-edit-invalid")
        let tool = CanvasEditTool { _, _, _ in .refused("This canvas is no longer on disk.") }
        let operation = CanvasOperation.reorder(CanvasElementID("b"), toIndex: 0)
        let result = await call(tool, operations: [try encoded(operation)], store: store)

        #expect(result.isError)
        #expect(result.text.contains("no longer on disk"))
    }

    @Test("a change without the revision that was read is refused naming its index")
    func missingRevisionIsRefused() async throws {
        let store = try makeTestStore("canvas-edit-revision")
        let tool = CanvasEditTool { _, operations, _ in
            var keeper = CanvasDocumentKeeper(
                opening: .read(try! CanvasDocumentCodec.encode(CanvasDocument(frames: [Self.frame], elements: [Self.box()])))
            )
            switch CanvasAgentEdit.begin(operations, on: &keeper) {
            case .refused(let sentence): return .refused(sentence)
            case .conflict(let conflicts): return .conflict(conflicts)
            case .pending(let pending): return .applied(CanvasAgentEdit.conclude(pending, on: keeper))
            }
        }
        let reorder = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        let update = try encoded(.updateElement(CanvasElementID("b"), expectedRevision: nil, CanvasElementPatch()))
        let result = await call(tool, operations: [reorder, update], store: store)

        #expect(result.isError)
        #expect(result.text.contains("expectedRevision"))
        #expect(result.text.contains("index 1"))
    }

    @Test("more than 500 operations are refused without calling the app")
    func tooManyOperationsIsRefused() async throws {
        let store = try makeTestStore("canvas-edit-many")
        let tool = CanvasEditTool { _, _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let operation = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        let tooMany = [JSONValue](repeating: operation, count: CanvasEditToolName.maxOperations + 1)

        let refused = await call(tool, operations: tooMany, store: store)

        #expect(refused.isError)
        #expect(refused.text.contains("500"))
        #expect(CanvasEditToolName.maxOperations == 500)
    }

    @Test("exactly 500 operations are passed on")
    func fiveHundredOperationsAreAccepted() async throws {
        let store = try makeTestStore("canvas-edit-limit")
        let tool = CanvasEditTool { _, operations, _ in
            #expect(operations.count == 500)
            return .applied(CanvasAgentEditResult(changes: CanvasChangeSummary(), operationCount: 500, disk: .saved))
        }
        let operation = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        let result = await call(tool, operations: [JSONValue](repeating: operation, count: 500), store: store)

        #expect(!result.isError)
    }

    @Test("a malformed operation is refused naming its index and what is wrong")
    func malformedOperationNamesTheProblem() async throws {
        let store = try makeTestStore("canvas-edit-malformed")
        let tool = CanvasEditTool { _, _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let good = try encoded(.reorder(CanvasElementID("b"), toIndex: 0))
        let unknown = JSONValue.object(["op": .string("explode"), "id": .string("b")])
        let missing = JSONValue.object(["op": .string("deleteElement")])

        let first = await call(tool, operations: [good, good, unknown], store: store)
        let second = await call(tool, operations: [good, missing], store: store)

        #expect(first.isError)
        #expect(first.text.contains("index 2"))
        #expect(first.text.contains("explode"))
        #expect(second.isError)
        #expect(second.text.contains("index 1"))
        #expect(second.text.contains("'id'"))
    }

    @Test("no path, no operations, or operations that are not a list are refused")
    func argumentsAreChecked() async throws {
        let store = try makeTestStore("canvas-edit-arguments")
        let tool = CanvasEditTool { _, _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let noPath = await tool.call(request(["operations": .array([])]), as: identity, store: store)
        let empty = await call(tool, operations: [], store: store)
        let notAList = await tool.call(
            request(["path": .string("c.udcanvas"), "operations": .string("x")]), as: identity, store: store
        )

        #expect(noPath.isError)
        #expect(empty.isError)
        #expect(notAList.isError)
    }

    @Test("an agent edit is refused while saving is held, and not for a notice the owner only has to read")
    func holdsRefuseAgentEdits() {
        let held: [CanvasDiskWarning] = [.refused("x"), .backupFailed("x"), .saveOverRefused("x"), .vanished]
        let notices: [CanvasDiskWarning] = [
            .saveFailed("x"), .reloaded(backups: [], typingKeptIn: []), .savedOver(backups: [], typingKeptIn: []),
            .copyKept(backups: [], typingKeptIn: []), .draftRescued,
        ]

        let allHeld = held.allSatisfy { $0.refusesAgentEdits }
        let noneNotice = notices.allSatisfy { !$0.refusesAgentEdits }
        #expect(allHeld)
        #expect(noneNotice)
    }

    @Test("an agent edits and renders a canvas without asking the owner each time", arguments: [
        "canvas_show", "canvas_read", "canvas_edit", "canvas_render", "canvas_comment_resolve",
    ])
    func canvasToolsApproveThemselves(tool: String) {
        #expect(BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + tool))
    }
}
