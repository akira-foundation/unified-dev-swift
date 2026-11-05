import Foundation
import Testing
@testable import Core

@Suite("A canvas that would be too large to reopen", .serialized)
struct CanvasDocumentSizeOnSaveTests {
    private let limit = CanvasDocumentFile.maximumBytes

    private func scratch() throws -> String {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-save-size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.path
    }

    private func text(_ id: String, bytes: Int) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .text(CanvasText(runs: [
                CanvasTextRun(text: String(repeating: "x", count: bytes), fontName: "Helvetica", size: 12, weight: 0, colour: "#000000"),
            ]))
        )
    }

    private func strokeDocument(points: Int) -> CanvasDocument {
        let many = (0..<points).map { CanvasPoint(x: Double($0 % 900), y: Double($0 % 70)) }
        return CanvasDocument(elements: [CanvasElement(
            id: CanvasElementID("ink"), rect: CanvasRect(x: 0, y: 0, width: 900, height: 70),
            kind: .stroke(CanvasStroke(points: many, width: 2, colour: "#000000"))
        )])
    }

    private func nearlyFull(_ path: String) throws -> Data {
        let data = try CanvasDocumentCodec.encode(CanvasDocument(elements: [text("full", bytes: limit - 1_000_000)]))
        try data.write(to: URL(filePath: path))
        return data
    }

    private func run(_ keeper: inout CanvasDocumentKeeper, on worker: CanvasDiskWorker) async {
        for _ in 0..<20 {
            guard let step = keeper.nextStep() else { return }
            keeper.finish(await worker.perform(step))
        }
        Issue.record("the keeper was still asking for steps after 20")
    }

    private func overfill(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([.addElement(text("more", bytes: 2_000_000))], by: .owner)
    }

    private func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return document
    }

    @Test func theReadableFormIsKeptWhileItFits() throws {
        let document = strokeDocument(points: 50)
        let pretty = try CanvasDocumentCodec.encode(document)
        #expect(try CanvasDocumentCodec.encodeForDisk(document, limit: pretty.count) == pretty)
    }

    @Test func oneByteOverTheLimitTheCompactFormIsWrittenAndReadsBackTheSame() throws {
        let document = strokeDocument(points: 50)
        let pretty = try CanvasDocumentCodec.encode(document)
        let compact = try CanvasDocumentCodec.encodeForDisk(document, limit: pretty.count - 1)
        #expect(compact.count < pretty.count)
        #expect(!compact.contains(UInt8(ascii: "\n")))
        #expect(CanvasDocumentCodec.decode(compact) == .document(document))
    }

    @Test func aCompactFormExactlyAtTheLimitIsAcceptedAndOneOverIsRefusedNamingItsSize() throws {
        let document = strokeDocument(points: 50)
        let pretty = try CanvasDocumentCodec.encode(document)
        let compact = try CanvasDocumentCodec.encodeForDisk(document, limit: pretty.count - 1)
        #expect(try CanvasDocumentCodec.encodeForDisk(document, limit: compact.count) == compact)
        #expect(throws: CanvasDocumentFile.TooLarge(size: compact.count)) {
            try CanvasDocumentCodec.encodeForDisk(document, limit: compact.count - 1)
        }
    }

    @Test func aMillionPointsSaveInCompactFormAndTheCanvasReopens() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/ink.udcanvas"
        let worker = CanvasDiskWorker(path: path)
        var opened = strokeDocument(points: 1_000_000)
        opened.elements.append(text("note", bytes: 1))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(opened).write(to: URL(filePath: path))
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))

        _ = keeper.apply([.deleteElement(CanvasElementID("note"), expectedRevision: nil)], by: .owner)
        await run(&keeper, on: worker)

        let size = try #require(FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
        print("MEASURE a million points save as \(size) bytes")
        #expect(size <= limit)
        #expect(keeper.warning == nil)
        let reopened = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        #expect(try held(reopened) == held(keeper))
    }

    @Test func aDocumentTooLargeEvenCompactIsNotWrittenAndTheEditsStayInMemory() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let original = try nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))

        overfill(&keeper)
        await run(&keeper, on: worker)

        guard case .tooLargeToSave(let size) = keeper.warning else {
            Issue.record("expected the size to be refused, got \(String(describing: keeper.warning))")
            return
        }
        #expect(size > limit)
        #expect(try Data(contentsOf: URL(filePath: path)) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory) == ["full.udcanvas"])
        #expect(try held(keeper).elements.contains { $0.id == CanvasElementID("more") })
        #expect(keeper.hasStrandedEdits)
    }

    @Test func theWarningNamesTheSizeAndTheLimitAndOffersNoRetry() {
        let warning = CanvasDiskWarning.tooLargeToSave(82_001_204)
        #expect(warning.message.contains("79 MB") && warning.message.contains("64 MB"))
        #expect(warning.message.contains("only there"))
        #expect(!warning.message.contains("tried again"))
        #expect(warning.actions.isEmpty)
        #expect(warning.tone == .error)
    }

    @Test func removingEnoughSavesAndLiftsTheWarning() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        _ = try nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        overfill(&keeper)
        await run(&keeper, on: worker)

        _ = keeper.apply([.deleteElement(CanvasElementID("full"), expectedRevision: nil)], by: .owner)
        await run(&keeper, on: worker)

        #expect(keeper.warning == nil)
        let reopened = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        #expect(try held(reopened) == held(keeper))
    }

    @Test func undoingBackToWhatIsOnDiskLiftsTheWarningWithoutWriting() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        let original = try nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        overfill(&keeper)
        await run(&keeper, on: worker)

        let undone = keeper.undo()
        #expect(undone)
        await run(&keeper, on: worker)

        #expect(keeper.warning == nil)
        #expect(try Data(contentsOf: URL(filePath: path)) == original)
    }

    @Test func savingOverWithADocumentTooLargeLeavesTheFileAndForgetsTheDeliberateSave() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        _ = try nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        overfill(&keeper)
        await run(&keeper, on: worker)
        let outside = Data("{ not json".utf8)
        try outside.write(to: URL(filePath: path))
        keeper.finish(CanvasDiskWorker.read(path))
        #expect(keeper.warning?.refusesAgentEdits == true)

        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        guard case .tooLargeToSave = keeper.warning else {
            Issue.record("expected the size to be refused, got \(String(describing: keeper.warning))")
            return
        }
        #expect(try Data(contentsOf: URL(filePath: path)) == outside)

        _ = keeper.apply([.deleteElement(CanvasElementID("full"), expectedRevision: nil)], by: .owner)
        keeper.perform(.tryAgain)
        guard case .save(_, let expecting)? = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        #expect(expecting != nil)
    }

    @Test func aFileChangedOutsideWhileTheDocumentIsTooLargeOffersNoActionThatCannotWork() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/full.udcanvas"
        _ = try nearlyFull(path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        overfill(&keeper)
        await run(&keeper, on: worker)
        let outside = try CanvasDocumentCodec.encode(CanvasDocument(elements: [text("theirs", bytes: 4)]))
        try outside.write(to: URL(filePath: path))

        keeper.finish(CanvasDiskWorker.read(path))
        await run(&keeper, on: worker)

        guard case .tooLargeToSave = keeper.warning else {
            Issue.record("expected the size to be refused, got \(String(describing: keeper.warning))")
            return
        }
        #expect(try Data(contentsOf: URL(filePath: path)) == outside)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory) == ["full.udcanvas"])
        #expect(try held(keeper).elements.contains { $0.id == CanvasElementID("more") })

        _ = keeper.apply([.deleteElement(CanvasElementID("full"), expectedRevision: nil)], by: .owner)
        await run(&keeper, on: worker)

        #expect(try held(keeper).elements.map(\.id) == [CanvasElementID("theirs")])
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).count == 2)
    }

    @Test(arguments: [nil, [Data()]] as [[Data]?])
    func theWorkerRefusesBytesOverTheLimitBeforeTouchingTheFile(expecting: [Data]?) async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let original = Data("{}".utf8)
        try original.write(to: URL(filePath: path))

        let result = await CanvasDiskWorker(path: path).perform(.save(Data(count: limit + 1), expecting: expecting))

        #expect(result == .tooLargeToWrite(limit + 1))
        #expect(try Data(contentsOf: URL(filePath: path)) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory) == ["deck.udcanvas"])
    }

    @Test func theWorkerAcceptsBytesExactlyAtTheLimit() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let result = await CanvasDiskWorker(path: path).perform(.save(Data(count: limit), expecting: nil))
        #expect(result == .written(Data(count: limit)))
    }

    @Test func noCopyIsWrittenThatCouldNotBeReopened() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let result = await CanvasDiskWorker(path: path).perform(.backup(Data(count: limit + 1)))
        guard case .backupFailed(let reason) = result else {
            Issue.record("expected the copy to be refused, got \(result)")
            return
        }
        #expect(reason.contains("64 MB"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).isEmpty)
    }

    @Test func writingADocumentTooLargeThrowsAndLeavesTheFile() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let original = Data("{}".utf8)
        try original.write(to: URL(filePath: path))
        let document = CanvasDocument(elements: [text("huge", bytes: limit + 1)])
        #expect(throws: CanvasDocumentFile.TooLarge.self) { try CanvasDocumentFile.write(document, to: path) }
        #expect(try Data(contentsOf: URL(filePath: path)) == original)
    }
}
