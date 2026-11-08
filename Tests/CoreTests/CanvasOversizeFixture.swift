import Foundation
import Testing
@testable import Core

struct CanvasOversizeFixture {
    let limit = CanvasDocumentFile.maximumBytes

    func scratch() throws -> String {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-oversize-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.path
    }

    func text(_ id: String, bytes: Int) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .text(CanvasText(runs: [
                CanvasTextRun(text: String(repeating: "x", count: bytes), fontName: "Helvetica", size: 12, weight: 0, colour: "#000000"),
            ]))
        )
    }

    func nearlyFull(_ path: String) throws -> Data {
        let data = try CanvasDocumentCodec.encode(CanvasDocument(elements: [text("full", bytes: limit - 1_000_000)]))
        try data.write(to: URL(filePath: path))
        return data
    }

    func overfill(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([.addElement(text("more", bytes: 2_000_000))], by: .owner)
    }

    func removeTheBulk(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([.deleteElement(CanvasElementID("full"), expectedRevision: nil)], by: .owner)
    }

    func run(_ keeper: inout CanvasDocumentKeeper, on worker: CanvasDiskWorker) async {
        for _ in 0..<20 {
            guard let step = keeper.nextStep() else { return }
            keeper.finish(await worker.perform(step))
        }
        Issue.record("the keeper was still asking for steps after 20")
    }

    func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else { throw CocoaError(.fileReadCorruptFile) }
        return document
    }

    func grow(_ path: String, by extra: Int = 1) throws {
        let handle = try FileHandle(forWritingTo: URL(filePath: path))
        try handle.truncate(atOffset: UInt64(limit + extra))
        try handle.close()
    }
}
