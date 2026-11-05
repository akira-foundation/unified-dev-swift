import Foundation
import Testing
@testable import Core

@Suite("Showing a workspace file in the canvas", .scratchDirectory)
struct CanvasShowToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func request(_ fields: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasShowToolName.show, params: .object(fields))
    }

    @Test("the tool hands a trimmed path, title, focus and caller to its own workspace")
    func call() async throws {
        let store = try makeTestStore("canvas-show")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request([
                "path": .string(" docs/a.html "),
                "title": .string(" Report "),
                "focus": .bool(false),
            ]),
            as: identity,
            store: store
        )

        #expect(!result.isError)
        #expect(
            await recorder.values == [
                Value(
                    order: CanvasShowOrder(
                        path: "docs/a.html", title: "Report", focus: false, caller: SessionID("s")
                    ),
                    workspaceID: WorkspaceID("w")
                ),
            ]
        )
    }

    @Test("focus defaults to true and an empty title is none")
    func defaults() async throws {
        let store = try makeTestStore("canvas-show-defaults")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        _ = await tool.call(
            request(["path": .string("a.md"), "title": .string("  ")]), as: identity, store: store
        )

        let orders = await recorder.values.map(\.order)
        #expect(orders == [CanvasShowOrder(path: "a.md", title: nil, focus: true, caller: SessionID("s"))])
    }

    @Test("an empty path is refused without calling the app")
    func emptyPath() async throws {
        let store = try makeTestStore("canvas-show-empty")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(request(["path": .string("  ")]), as: identity, store: store)

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a caller with no workspace is refused")
    func noWorkspace() async throws {
        let store = try makeTestStore("canvas-show-scope")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request(["path": .string("a.md")]),
            as: BridgeIdentity(ownerSession: SessionID("s")),
            store: store
        )

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a focus that is not a boolean is refused without calling the app")
    func badFocus() async throws {
        let store = try makeTestStore("canvas-show-focus")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request(["path": .string("a.md"), "focus": .string("no")]), as: identity, store: store
        )

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a refusal from the app is an error result")
    func refusal() async throws {
        let store = try makeTestStore("canvas-show-refusal")
        let tool = CanvasShowTool { _, _ in .refused("x") }
        let result = await tool.call(request(["path": .string("a.md")]), as: identity, store: store)

        #expect(result.isError)
        #expect(result.text == "x")
    }

    @Test("canvas_show approves itself")
    func approval() {
        #expect(
            BridgeToolApproval.isSelfApproved(
                toolName: BridgeToolApproval.toolPrefix + CanvasShowToolName.show
            )
        )
    }

    @Test("every format the description names is one the canvas accepts, and every accepted one is named")
    func description() {
        let text = CanvasShowTool { _, _ in .refused("x") }.tool.description
        let formats: [String: String] = [
            "HTML": "html", "Markdown": "md", "SVG": "svg", "PNG": "png", "JPEG": "jpeg",
            "GIF": "gif", "WebP": "webp", "PDF": "pdf", "TIFF": "tiff", "HEIC": "heic",
            "BMP": "bmp", "AVIF": "avif", "ICO": "ico", "JSON": "json", "CSV": "csv",
        ]
        let named = formats.filter { text.contains($0.key) }

        for (word, ext) in named {
            #expect(CanvasFile.extensions.contains(ext), "the description names \(word)")
        }
        for (word, ext) in formats where CanvasFile.extensions.contains(ext) {
            #expect(named[word] != nil, "the description leaves out \(word)")
        }
    }

    private struct Value: Sendable, Equatable {
        var order: CanvasShowOrder
        var workspaceID: WorkspaceID
    }

    private actor Recorder {
        var values: [Value] = []
        func record(_ order: CanvasShowOrder, workspaceID: WorkspaceID) {
            values.append(Value(order: order, workspaceID: workspaceID))
        }
    }
}

@Suite("Who may create a canvas by showing it", .scratchDirectory)
struct CanvasShowCreatingTests {
    private let worktree: URL

    init() throws {
        worktree = FileManager.default.temporaryDirectory.appending(path: "canvas-show-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
    }

    private func order(mayCreate: Bool) -> CanvasShowOrder {
        CanvasShowOrder(path: "canvases/new.udcanvas", mayCreate: mayCreate)
    }

    private var folder: String { worktree.appending(path: "canvases").path }

    private func seeded(_ store: Store, name: String) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: "b/\(name)", path: TestScratch.unique(name), baseBranch: "main"
        ))
    }

    @Test func anOrchestratorsOrderMayNotCreate() async throws {
        let store = try makeTestStore("canvas-show-orchestrator")
        let workspace = try await seeded(store, name: "lead")
        try await store.setOrchestrator(true, workspaceID: workspace.id)
        let caller = BridgeIdentity(sessionID: SessionID("s"), workspaceID: workspace.id, role: .workspace)
        let box = OrderBox()
        let tool = CanvasShowTool { order, _ in
            box.order = order
            return .shown("shown")
        }

        _ = await tool.call(MCPRequest(id: .integer(1), method: CanvasShowToolName.show, params: .object(["path": .string("a.udcanvas")])), as: caller, store: store)

        #expect(box.order?.mayCreate == false)
    }

    @Test func anOrdinaryWorkspacesOrderMayCreate() async throws {
        let store = try makeTestStore("canvas-show-ordinary")
        let workspace = try await seeded(store, name: "plain")
        let caller = BridgeIdentity(sessionID: SessionID("s"), workspaceID: workspace.id, role: .workspace)
        let box = OrderBox()
        let tool = CanvasShowTool { order, _ in
            box.order = order
            return .shown("shown")
        }

        _ = await tool.call(MCPRequest(id: .integer(1), method: CanvasShowToolName.show, params: .object(["path": .string("a.udcanvas")])), as: caller, store: store)

        #expect(box.order?.mayCreate == true)
    }

    @Test func anOrderThatMayNotCreateIsRefusedAndWritesNothing() {
        let answer = CanvasFile.showing(order(mayCreate: false), worktree: worktree.path)

        #expect((try? answer.get()) == nil)
        #expect(!FileManager.default.fileExists(atPath: folder))
    }

    @Test func anOrderThatMayCreateMakesTheDocumentAndSaysSo() throws {
        let target = try CanvasFile.showing(order(mayCreate: true), worktree: worktree.path).get()

        #expect(target.created)
        #expect(FileManager.default.fileExists(atPath: target.absolute))
        #expect(target.followUp.contains("blank"))
        #expect(target.followUp.contains("canvas_edit"))
    }

    @Test func aDocumentAlreadyThereCanBeShownByAnyoneAndIsNotCalledNew() throws {
        _ = try CanvasFile.showing(order(mayCreate: true), worktree: worktree.path).get()

        let target = try CanvasFile.showing(order(mayCreate: false), worktree: worktree.path).get()

        #expect(!target.created)
        #expect(!target.followUp.contains("blank"))
        #expect(target.followUp.contains("canvas_read"))
    }

    @Test func aFileThatIsNotACanvasSaysNothingAboutCanvasTools() throws {
        try Data().write(to: worktree.appending(path: "a.html"))
        let target = try CanvasFile.showing(CanvasShowOrder(path: "a.html"), worktree: worktree.path).get()
        #expect(target.followUp.isEmpty)
    }

    @Test func theToolTellsAnAgentACanvasCanBeCreatedAndWhatFollows() {
        let description = CanvasShowTool { _, _ in .refused("x") }.tool.description
        for name in [".udcanvas", "blank", "canvas_read", "canvas_edit", "canvas_render", "orchestrator"] {
            #expect(description.contains(name))
        }
    }

    @Test func theToolsThatTakeACanvasNameItsExtension() {
        let descriptions = [
            CanvasReadTool { _, _ in .refused("x") }.tool.description,
            CanvasEditTool { _, _, _ in .refused("x") }.tool.description,
            CanvasRenderTool { _, _, _ in .refused("x") }.tool.description,
            CanvasCommentResolveTool { _, _ in .refused("x") }.tool.description,
        ]
        for description in descriptions { #expect(description.contains(".udcanvas")) }
    }
}

private final class OrderBox: @unchecked Sendable {
    var order: CanvasShowOrder?
}
