import Foundation
import Testing
@testable import Core

@Suite("Reading a canvas document", .scratchDirectory)
struct CanvasReadToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func request(_ fields: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasReadToolName.read, params: .object(fields))
    }

    private var document: CanvasDocument {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 10, height: 10))
        let text = CanvasElement(
            id: CanvasElementID("t"), frameID: frame.id, revision: 4,
            rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: "Hi", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")]))
        )
        func comment(_ id: String, _ state: CanvasComment.State) -> CanvasComment {
            CanvasComment(id: CanvasCommentID(id), anchor: CanvasPoint(x: 1, y: 1), text: id, state: state, createdAt: Date(timeIntervalSince1970: 0))
        }
        return CanvasDocument(
            frames: [frame], elements: [text],
            comments: [comment("queued", .queued), comment("working", .working), comment("done", .resolved), comment("no", .declined), comment("lost", .unanswered)]
        )
    }

    @Test("the document comes back with only the comments still to be dealt with, and the measured size of each text")
    func readReturnsDocumentAndOpenComments() async throws {
        let store = try makeTestStore("canvas-read")
        let document = document
        let tool = CanvasReadTool { path, workspaceID in
            #expect(path == "c.udcanvas")
            #expect(workspaceID == WorkspaceID("w"))
            return .read(CanvasReadAnswer(document: document, measuredTextSize: [CanvasElementID("t"): CanvasSize(width: 8, height: 15)]))
        }
        let result = await tool.call(request(["path": .string(" c.udcanvas ")]), as: identity, store: store)

        #expect(!result.isError)
        let json = try #require(JSONValue.parse(Data(result.text.utf8)))
        guard case .object(let fields) = json, case .object(let body)? = fields["document"] else {
            Issue.record("no document in \(result.text)")
            return
        }
        #expect(body["comments"] == nil)
        guard case .array(let open)? = fields["openComments"] else {
            Issue.record("no openComments")
            return
        }
        let ids = open.compactMap { value -> String? in
            guard case .object(let comment) = value, case .string(let id)? = comment["id"] else { return nil }
            return id
        }
        #expect(ids == ["queued", "working", "lost"])
        guard case .object(let measured)? = fields["measuredTextSize"], case .object(let size)? = measured["t"] else {
            Issue.record("no measuredTextSize")
            return
        }
        #expect(size["width"] == .number(8) || size["width"] == .integer(8))
        guard case .array(let elements)? = body["elements"], case .object(let first)? = elements.first else {
            Issue.record("no elements")
            return
        }
        #expect(first["revision"] == .integer(4))
    }

    @Test("a read with no path is refused without calling the app")
    func readNeedsAPath() async throws {
        let store = try makeTestStore("canvas-read-path")
        let tool = CanvasReadTool { _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let result = await tool.call(request(["path": .string("  ")]), as: identity, store: store)

        #expect(result.isError)
    }

    @Test("a caller with no workspace is refused")
    func readRefusesOutsideWorkspace() async throws {
        let store = try makeTestStore("canvas-read-scope")
        let tool = CanvasReadTool { _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let result = await tool.call(
            request(["path": .string("c.udcanvas")]), as: BridgeIdentity(ownerSession: SessionID("s")), store: store
        )

        #expect(result.isError)
    }

    @Test("a refusal from the app, such as a corrupt document, is an error carrying its reason")
    func refusalCarriesReason() async throws {
        let store = try makeTestStore("canvas-read-refusal")
        let tool = CanvasReadTool { _, _ in .refused("This canvas cannot be read: bad") }
        let result = await tool.call(request(["path": .string("c.udcanvas")]), as: identity, store: store)

        #expect(result.isError)
        #expect(result.text == "This canvas cannot be read: bad")
    }

    @Test("canvas_read approves itself")
    func approval() {
        #expect(
            BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + CanvasReadToolName.read)
        )
    }
}
