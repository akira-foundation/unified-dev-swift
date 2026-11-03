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
        let json = try #require(JSONValue.parse(Data(result.text.utf8)))
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
        let changed = CanvasDocument(frames: [Self.frame], elements: [Self.box(revision: 4)])
        let operation = CanvasOperation.updateElement(
            CanvasElementID("b"), expectedRevision: 3,
            CanvasElementPatch(rect: CanvasRect(x: 5, y: 5, width: 10, height: 10))
        )
        let tool = CanvasEditTool { path, operations, workspaceID in
            #expect(path == "c.udcanvas")
            #expect(workspaceID == WorkspaceID("w"))
            #expect(operations == [operation])
            return .applied(changed)
        }
        let result = await call(tool, operations: [try encoded(operation)], store: store)

        #expect(!result.isError)
        let answer = try fields(of: result)
        #expect(answer["applied"] == .bool(true))
        guard case .object(let document)? = answer["document"], case .array(let elements)? = document["elements"],
              case .object(let first)? = elements.first else {
            Issue.record("no document in \(result.text)")
            return
        }
        #expect(first["revision"] == .integer(4))
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
        let tool = CanvasEditTool { _, _, _ in .invalid("This canvas is no longer on disk.") }
        let operation = CanvasOperation.reorder(CanvasElementID("b"), toIndex: 0)
        let result = await call(tool, operations: [try encoded(operation)], store: store)

        #expect(result.isError)
        #expect(result.text.contains("no longer on disk"))
    }

    @Test("a change without the revision that was read is refused naming its index")
    func missingRevisionIsRefused() async throws {
        let store = try makeTestStore("canvas-edit-revision")
        let tool = CanvasEditTool { _, operations, _ in
            var session = CanvasDocumentSession(document: CanvasDocument(frames: [Self.frame], elements: [Self.box()]))
            return session.apply(operations, by: .agent)
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
            return .invalid("x")
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
            return .applied(CanvasDocument())
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
            return .invalid("x")
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
            return .invalid("x")
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

    @Test("the operations an agent writes from the description decode")
    func describedShapesDecode() throws {
        let element = JSONValue.object([
            "op": .string("addElement"),
            "element": .object([
                "id": .string("n"), "frameID": .string("f"), "revision": .integer(0),
                "rect": .object([
                    "origin": .object(["x": .integer(1), "y": .integer(2)]),
                    "size": .object(["width": .integer(30), "height": .integer(40)]),
                ]),
                "style": .object([
                    "strokeWidth": .integer(0), "cornerRadius": .integer(0), "opacity": .integer(1), "rotation": .integer(0),
                ]),
                "kind": .object(["shape": .object(["_0": .object(["kind": .string("ellipse")])])]),
            ]),
        ])
        let decoded = try JSONDecoder().decode(CanvasOperation.self, from: JSONEncoder().encode(element))

        guard case .addElement(let added) = decoded else {
            Issue.record("not an addElement")
            return
        }
        #expect(added.kind == .shape(CanvasShape(kind: .ellipse)))
    }

    @Test("the schema names every operation the decoder knows")
    func schemaListsEveryOperation() {
        let listing = CanvasEditTool { _, _, _ in .invalid("x") }.tool.listing
        let text = String(describing: listing)

        for name in ["addFrame", "updateFrame", "deleteFrame", "addElement", "updateElement", "deleteElement", "reorder"] {
            #expect(text.contains(name))
        }
        #expect(text.contains("500"))
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
}
