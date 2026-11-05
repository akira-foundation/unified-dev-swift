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
        guard case .saveOverRefused = result else {
            Issue.record("expected the save to be refused, got \(result)")
            return
        }
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
}
