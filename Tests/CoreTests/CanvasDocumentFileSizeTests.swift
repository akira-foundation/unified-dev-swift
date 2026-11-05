import Foundation
import Testing
@testable import Core

@Suite("A canvas file too large to open")
struct CanvasDocumentFileSizeTests {
    private func file(sized bytes: Int) throws -> (directory: String, path: String) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "canvas-size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: "big.udcanvas").path
        FileManager.default.createFile(atPath: path, contents: nil)
        let handle = try FileHandle(forWritingTo: URL(filePath: path))
        try handle.truncate(atOffset: UInt64(bytes))
        try handle.close()
        return (directory.path, path)
    }

    private func size(of path: String) throws -> Int {
        try #require(FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
    }

    @Test func aFileOneByteOverTheLimitIsRefusedByNameAndLeftAlone() throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes + 1)
        guard case .unreadable(let reason) = CanvasDiskWorker.read(made.path) else {
            Issue.record("expected the read to be refused")
            return
        }
        #expect(reason.contains("64 MB") && reason.contains("left as it is"))
        #expect(try size(of: made.path) == CanvasDocumentFile.maximumBytes + 1)
    }

    @Test func aFileExactlyAtTheLimitIsRead() throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes)
        guard case .read(let data) = CanvasDiskWorker.read(made.path) else {
            Issue.record("expected the file to be read")
            return
        }
        #expect(data?.count == CanvasDocumentFile.maximumBytes)
    }

    @Test func theTabShowsTheReasonAsForACorruptDocument() throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes + 1)
        let keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(made.path))
        guard case .corrupt(let reason) = keeper.document else {
            Issue.record("expected a refusal, got \(keeper.document)")
            return
        }
        #expect(reason.contains("64 MB"))
    }

    @Test func savingOverAFileTooLargeToReadIsRefusedAndWritesNothing() async throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes + 1)
        let result = await CanvasDiskWorker(path: made.path).perform(.save(Data("{}".utf8), expecting: nil))
        #expect(result == .saveOverTooLarge(CanvasDocumentFile.maximumBytes + 1))
        #expect(try size(of: made.path) == CanvasDocumentFile.maximumBytes + 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: made.directory) == ["big.udcanvas"])
    }

    @Test func aGuardedSaveOverAFileTooLargeToReadWritesNothing() async throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes + 1)
        let result = await CanvasDiskWorker(path: made.path).perform(.save(Data("{}".utf8), expecting: [Data()]))
        guard case .writeFailed = result else {
            Issue.record("expected a failed write, got \(result)")
            return
        }
        #expect(try size(of: made.path) == CanvasDocumentFile.maximumBytes + 1)
    }

    @Test func aLinkToAFileOverTheLimitIsRefusedAndLeftAlone() throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes + 1)
        let link = made.directory + "/link.udcanvas"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: made.path)
        guard case .unreadable(let reason) = CanvasDiskWorker.read(link) else {
            Issue.record("expected the link to be refused")
            return
        }
        #expect(reason.contains("64 MB"))
        #expect(try size(of: made.path) == CanvasDocumentFile.maximumBytes + 1)
    }

    @Test func aLinkToAFileExactlyAtTheLimitIsRead() throws {
        let made = try file(sized: CanvasDocumentFile.maximumBytes)
        let link = made.directory + "/link.udcanvas"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: made.path)
        #expect(try CanvasDocumentFile.bytes(at: link)?.count == CanvasDocumentFile.maximumBytes)
    }

    @Test func aFileThatGrowsPastTheLimitAfterItWasMeasuredIsRefused() throws {
        let made = try file(sized: 100)
        #expect(throws: CanvasDocumentFile.TooLarge(size: 1_025)) {
            try CanvasDocumentFile.bytes(at: made.path, limit: 1_024) {
                let handle = try FileHandle(forWritingTo: URL(filePath: made.path))
                try handle.truncate(atOffset: 5_000)
                try handle.close()
            }
        }
    }

    @Test func aFileThatGrowsToExactlyTheLimitAfterItWasMeasuredIsRead() throws {
        let made = try file(sized: 100)
        let data = try CanvasDocumentFile.bytes(at: made.path, limit: 1_024) {
            let handle = try FileHandle(forWritingTo: URL(filePath: made.path))
            try handle.truncate(atOffset: 1_024)
            try handle.close()
        }
        #expect(data?.count == 1_024)
    }

    @Test func aPipeIsRefusedWithoutWaitingForAWriter() throws {
        let made = try file(sized: 0)
        let pipe = made.directory + "/pipe.udcanvas"
        #expect(mkfifo(pipe, 0o600) == 0)
        let finished = DispatchSemaphore(value: 0)
        Task {
            do {
                _ = try CanvasDocumentFile.bytes(at: pipe)
                Issue.record("expected the pipe to be refused")
            } catch {
                #expect(error is CanvasDocumentFile.NotAFile)
            }
            finished.signal()
        }
        if finished.wait(timeout: .now() + 5) == .timedOut {
            Issue.record("the read waited for a writer")
            close(open(pipe, O_WRONLY | O_NONBLOCK))
            finished.wait()
        }
    }

    @Test func aDanglingLinkReadsAsGone() throws {
        let made = try file(sized: 0)
        let link = made.directory + "/link.udcanvas"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: made.directory + "/absent")
        #expect(try CanvasDocumentFile.bytes(at: link) == nil)
    }

    @Test func aPathThroughAFileIsAFailureAndNotAMissingFile() throws {
        let made = try file(sized: 0)
        #expect(throws: (any Error).self) { try CanvasDocumentFile.bytes(at: made.path + "/inner.udcanvas") }
    }

    private var mine: CanvasDocument {
        CanvasDocument(elements: [CanvasElement(
            id: CanvasElementID("mine"), rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .shape(CanvasShape(kind: .rectangle))
        )])
    }

    private func grow(_ path: String) throws {
        let handle = try FileHandle(forWritingTo: URL(filePath: path))
        try handle.truncate(atOffset: UInt64(CanvasDocumentFile.maximumBytes + 1))
        try handle.close()
    }

    private func run(_ keeper: inout CanvasDocumentKeeper, on worker: CanvasDiskWorker) async {
        for _ in 0..<20 {
            guard let step = keeper.nextStep() else { return }
            keeper.finish(await worker.perform(step))
        }
        Issue.record("the keeper was still asking for steps after 20")
    }

    private func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else { throw CocoaError(.fileReadCorruptFile) }
        return document
    }

    @Test func savingOverAFileTooLargeSaysWhatHappenedAndWhatToDo() {
        let warning = CanvasDiskWarning.fileTooLarge(CanvasDocumentFile.maximumBytes + 1)
        #expect(warning.message.contains("65 MB") && warning.message.contains("64 MB"))
        #expect(warning.message.contains("Move that file"))
        #expect(warning.message.contains(CanvasDiskWarningAction.saveOver.title))
        #expect(!warning.message.contains("could not be written"))
        #expect(warning.actions == [.saveOver, .reload])
        #expect(warning.refusesAgentEdits)
    }

    @Test func savingOverAFileTooLargeHoldsItUntilTheFileIsMovedAndThenSaves() async throws {
        let directory = try file(sized: 0).directory
        let path = directory + "/deck.udcanvas"
        try CanvasDocumentFile.write(mine, to: path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        try grow(path)
        keeper.finish(CanvasDiskWorker.read(path))

        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        #expect(keeper.warning == .fileTooLarge(CanvasDocumentFile.maximumBytes + 1))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).filter { $0 != "big.udcanvas" } == ["deck.udcanvas"])
        #expect(try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int == CanvasDocumentFile.maximumBytes + 1)

        try FileManager.default.moveItem(atPath: path, toPath: directory + "/aside")
        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        #expect(keeper.warning == nil)
        let reopened = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        #expect(try held(reopened) == held(keeper))
    }

    @Test func savingOverAFileMadeSmallerKeepsACopyAndSaves() async throws {
        let directory = try file(sized: 0).directory
        let path = directory + "/deck.udcanvas"
        try CanvasDocumentFile.write(mine, to: path)
        let worker = CanvasDiskWorker(path: path)
        var keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        try grow(path)
        keeper.finish(CanvasDiskWorker.read(path))
        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        try Data("{ not json".utf8).write(to: URL(filePath: path))
        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        guard case .savedOver = keeper.warning else {
            Issue.record("expected the file to be replaced, got \(String(describing: keeper.warning))")
            return
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).filter { $0 != "big.udcanvas" }.count == 2)
    }
}
