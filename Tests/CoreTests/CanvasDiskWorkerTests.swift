import Foundation
import Testing
@testable import Core

@Suite("CanvasDiskWorker")
struct CanvasDiskWorkerTests {
    private let fixture = CanvasSessionFixture()
    private let stepLimit = 20

    private func scratch() throws -> String {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-disk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.path
    }

    private func run(_ keeper: inout CanvasDocumentKeeper, on worker: CanvasDiskWorker) async {
        for _ in 0..<stepLimit {
            guard let step = keeper.nextStep() else { return }
            keeper.finish(await worker.perform(step))
        }
        Issue.record("the keeper was still asking for steps after \(stepLimit)")
    }

    private func write(_ text: String, to path: String) throws {
        try Data(text.utf8).write(to: URL(filePath: path))
    }

    private func open(_ path: String) throws -> CanvasDocumentKeeper {
        try CanvasDocumentFile.write(fixture.session().document, to: path)
        return CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
    }

    private func onDisk(_ path: String) throws -> CanvasDocument? {
        if case .document(let document) = try CanvasDocumentFile.read(at: path) { return document }
        return nil
    }

    @Test func anEditSurvivesLeavingAndComingBack() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)

        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        await run(&keeper, on: worker)

        let reopened = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(path))
        #expect(reopened.document == keeper.document)
        guard case .document(let document) = reopened.document else {
            Issue.record("the saved file did not read back: \(reopened.document)")
            return
        }
        #expect(document.elements.first { $0.id == fixture.boxID }?.rect.origin.x == 9)
    }

    @Test func ourOwnSaveIsNotTakenForAnOutsideChange() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        keeper.perform(.reload)
        await run(&keeper, on: worker)

        keeper.perform(.reload)
        await run(&keeper, on: worker)

        #expect(keeper.reloads == 0)
        #expect(keeper.warning == nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory)
        #expect(files == ["deck.udcanvas"])
    }

    @Test func anOutsideChangeRacingAnEditIsNotOverwrittenAndTheEditIsKeptInACopy() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)
        var outside = fixture.session().document
        outside.frames[0].name = "From git"
        try CanvasDocumentFile.write(outside, to: path)

        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let edited = keeper.document
        await run(&keeper, on: worker)

        #expect(try onDisk(path)?.frames[0].name == "From git")
        guard case .document(let reloaded) = keeper.document, case .reloaded(let backups, _) = keeper.warning,
              let backup = backups.last else {
            Issue.record("expected a reload notice, got \(String(describing: keeper.warning))")
            return
        }
        #expect(reloaded.frames[0].name == "From git")
        #expect(try CanvasDocumentFile.read(at: backup) == edited)
        #expect((backup as NSString).lastPathComponent.hasPrefix("deck.udcanvas.backup-"))
    }

    @Test func aFailedWriteLeavesTheFileAsItWas() async throws {
        let directory = try scratch()
        let locked = directory + "/locked"
        try FileManager.default.createDirectory(atPath: locked, withIntermediateDirectories: true)
        let path = locked + "/deck.udcanvas"
        var keeper = try open(path)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
            try? FileManager.default.removeItem(atPath: directory)
        }
        let worker = CanvasDiskWorker(path: path)

        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let edited = keeper.document
        await run(&keeper, on: worker)

        guard case .saveFailed = keeper.warning else {
            Issue.record("expected a failed save, got \(String(describing: keeper.warning))")
            return
        }
        #expect(keeper.document == edited)
        #expect(try onDisk(path) == fixture.session().document)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
        _ = keeper.apply([fixture.move(fixture.titleID, revision: nil)], by: .owner)
        await run(&keeper, on: worker)
        #expect(keeper.warning == nil)
        #expect(.document(try #require(try onDisk(path))) == keeper.document)
    }

    @Test func aBackupThatCannotBeWrittenLeavesEverythingWhereItWas() async throws {
        let directory = try scratch()
        let locked = directory + "/locked"
        try FileManager.default.createDirectory(atPath: locked, withIntermediateDirectories: true)
        let path = locked + "/deck.udcanvas"
        var keeper = try open(path)
        let held = keeper.document
        var outside = fixture.session().document
        outside.frames[0].name = "From git"
        try CanvasDocumentFile.write(outside, to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
            try? FileManager.default.removeItem(atPath: directory)
        }

        keeper.perform(.reload)
        await run(&keeper, on: CanvasDiskWorker(path: path))

        #expect(keeper.document == held)
        guard case .backupFailed = keeper.warning else {
            Issue.record("expected a refused backup, got \(String(describing: keeper.warning))")
            return
        }
    }

    @Test func aDeletedFileIsNotRecreatedUntilTheOwnerSaysSo() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let folder = directory + "/canvases"
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let path = folder + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)
        try FileManager.default.removeItem(atPath: folder)

        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        await run(&keeper, on: worker)

        #expect(keeper.warning == .vanished)
        #expect(!FileManager.default.fileExists(atPath: path))

        keeper.perform(.saveAgain)
        await run(&keeper, on: worker)

        #expect(keeper.warning == nil)
        #expect(.document(try #require(try onDisk(path))) == keeper.document)
    }

    @Test func aCorruptFileIsLeftAloneUntilTheOwnerSavesOverIt() async throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)
        try write("{ not json", to: path)

        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        await run(&keeper, on: worker)

        #expect(try Data(contentsOf: URL(filePath: path)) == Data("{ not json".utf8))
        guard case .refused = keeper.warning else {
            Issue.record("expected a refusal, got \(String(describing: keeper.warning))")
            return
        }

        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        #expect(.document(try #require(try onDisk(path))) == keeper.document)
        guard case .savedOver(let backups) = keeper.warning, let backup = backups.first else {
            Issue.record("expected the copy to be named, got \(String(describing: keeper.warning))")
            return
        }
        #expect(try Data(contentsOf: URL(filePath: backup)) == Data("{ not json".utf8))
        #expect(keeper.warning?.message.contains((backup as NSString).lastPathComponent) == true)
    }

    @Test func aSaveOverWhoseCopyCannotBeWrittenLeavesTheFileAlone() async throws {
        let directory = try scratch()
        let locked = directory + "/locked"
        try FileManager.default.createDirectory(atPath: locked, withIntermediateDirectories: true)
        let path = locked + "/deck.udcanvas"
        var keeper = try open(path)
        let worker = CanvasDiskWorker(path: path)
        try write("{ not json", to: path)
        keeper.perform(.reload)
        await run(&keeper, on: worker)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked)
            try? FileManager.default.removeItem(atPath: directory)
        }

        keeper.perform(.saveOver)
        await run(&keeper, on: worker)

        #expect(try Data(contentsOf: URL(filePath: path)) == Data("{ not json".utf8))
        guard case .saveOverRefused = keeper.warning else {
            Issue.record("expected a refusal, got \(String(describing: keeper.warning))")
            return
        }
        #expect(keeper.warning?.actions == [.saveOver, .reload])
    }

    @Test func twoCopiesInTheSameSecondDoNotOverwriteEachOther() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/deck.udcanvas"
        let moment = Date(timeIntervalSince1970: 1_000)

        let first = try CanvasDocumentFile.writeBackup(Data("one".utf8), beside: path, at: moment)
        let second = try CanvasDocumentFile.writeBackup(Data("two".utf8), beside: path, at: moment)

        #expect(first == CanvasDocumentFile.backupPath(for: path, at: moment))
        #expect(first != second)
        #expect(try Data(contentsOf: URL(filePath: first)) == Data("one".utf8))
        #expect(try Data(contentsOf: URL(filePath: second)) == Data("two".utf8))
    }

    @Test func onlyAMissingFileReadsAsGone() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        #expect(try CanvasDocumentFile.bytes(at: directory + "/absent.udcanvas") == nil)
        #expect(throws: (any Error).self) { try CanvasDocumentFile.bytes(at: directory) }
    }
}
