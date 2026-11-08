import Foundation
import Testing
@testable import Core

@Suite("A symbolic link at a canvas file")
struct CanvasDocumentFileLinkTests {
    private struct Bench {
        let root: String
        let canvas: String
        let secret: String

        init() throws {
            let made = FileManager.default.temporaryDirectory.appending(path: "canvas-link-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
            root = made.resolvingSymlinksInPath().path
            canvas = root + "/deck.udcanvas"
            secret = root + "/private.txt"
            try Data("private".utf8).write(to: URL(filePath: secret))
        }

        func swapCanvasForLink() throws {
            try? FileManager.default.removeItem(atPath: canvas)
            try FileManager.default.createSymbolicLink(atPath: canvas, withDestinationPath: secret)
        }

        var names: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []).sorted() }
    }

    @Test func aReadIsRefusedWithItsOwnReasonAndDoesNotFollow() throws {
        let bench = try Bench()
        defer { try? FileManager.default.removeItem(atPath: bench.root) }
        try bench.swapCanvasForLink()

        #expect(throws: CanvasDocumentFile.IsLink()) { try CanvasDocumentFile.bytes(at: bench.canvas) }
        guard case .unreadable(let reason) = CanvasDiskWorker.read(bench.canvas) else {
            Issue.record("expected a refusal, got \(CanvasDiskWorker.read(bench.canvas))")
            return
        }
        #expect(reason.contains("symbolic link"))
    }

    @Test func aDanglingLinkIsALinkAndNotAMissingFile() throws {
        let bench = try Bench()
        defer { try? FileManager.default.removeItem(atPath: bench.root) }
        try FileManager.default.createSymbolicLink(atPath: bench.canvas, withDestinationPath: bench.root + "/absent")
        #expect(throws: CanvasDocumentFile.IsLink()) { try CanvasDocumentFile.bytes(at: bench.canvas) }
    }

    @Test func saveOverCopiesNothingThroughALinkAndLeavesItThere() async throws {
        let bench = try Bench()
        defer { try? FileManager.default.removeItem(atPath: bench.root) }
        try bench.swapCanvasForLink()
        let before = bench.names

        let worker = CanvasDiskWorker(path: bench.canvas)
        let result = await worker.perform(.save(try CanvasDocumentCodec.encode(CanvasDocument()), expecting: nil))

        guard case .saveOverRefused(let reason) = result else {
            Issue.record("expected a refusal, got \(result)")
            return
        }
        #expect(reason.contains("symbolic link"))
        #expect(bench.names == before)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: bench.canvas) == bench.secret)
    }

    @Test func aSwapUnderAnOpenCanvasHoldsItWithTheReason() async throws {
        let bench = try Bench()
        defer { try? FileManager.default.removeItem(atPath: bench.root) }
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "Mine", rect: CanvasRect(x: 0, y: 0, width: 9, height: 9))
        try CanvasDocumentFile.write(CanvasDocument(frames: [frame]), to: bench.canvas)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(bench.canvas))
        try bench.swapCanvasForLink()

        keeper.perform(.reload)
        let worker = CanvasDiskWorker(path: bench.canvas)
        while let step = keeper.nextStep() { keeper.finish(await worker.perform(step)) }

        #expect(keeper.warning?.refusesAgentEdits == true)
        #expect(keeper.warning?.message.contains("symbolic link") == true)
        guard case .document(let held) = keeper.document else {
            Issue.record("the canvas in the tab is gone: \(keeper.document)")
            return
        }
        #expect(held.frames.first?.name == "Mine")
    }

    @Test func aPathThatIsALinkWhenFirstOpenedStillOpensThroughItsTarget() throws {
        let bench = try Bench()
        defer { try? FileManager.default.removeItem(atPath: bench.root) }
        let real = bench.root + "/real.udcanvas"
        let document = CanvasDocument(frames: [CanvasFrame(name: "Linked", rect: CanvasRect(x: 0, y: 0, width: 9, height: 9))])
        try CanvasDocumentFile.write(document, to: real)
        try FileManager.default.createSymbolicLink(atPath: bench.canvas, withDestinationPath: real)

        guard case .file(let absolute, _) = CanvasFile.contained(path: "deck.udcanvas", worktree: bench.root) else {
            Issue.record("the link did not resolve")
            return
        }
        #expect(absolute == real)
        #expect(try CanvasDocumentFile.read(at: absolute) == .document(document))
    }

    @Test func aLinkPointingOutOfTheWorktreeIsRefusedAtTheDoor() throws {
        let bench = try Bench()
        let elsewhere = try Bench()
        defer {
            try? FileManager.default.removeItem(atPath: bench.root)
            try? FileManager.default.removeItem(atPath: elsewhere.root)
        }
        try FileManager.default.createSymbolicLink(atPath: bench.canvas, withDestinationPath: elsewhere.secret)
        guard case .refused = CanvasFile.contained(path: "deck.udcanvas", worktree: bench.root) else {
            Issue.record("a link out of the worktree was accepted")
            return
        }
    }
}
