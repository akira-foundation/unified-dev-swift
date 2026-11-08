import Foundation
import Testing
@testable import Core

extension CanvasDiskWorker {
    init(path: String) {
        self.init(path: path, worktree: (path as NSString).deletingLastPathComponent)
    }
}

@Suite("A canvas whose folder became a link out of the workspace")
struct CanvasDiskWorkerContainmentTests {
    private let worktree: URL
    private let outside: URL
    private let path: String
    private let outsideFile: URL
    private let original = Data("outside".utf8)

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "canvas-worker-\(UUID().uuidString)").resolvingSymlinksInPath()
        worktree = base.appending(path: "worktree")
        outside = base.appending(path: "outside")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        outsideFile = outside.appending(path: "deck.udcanvas")
        try original.write(to: outsideFile)
        try FileManager.default.createSymbolicLink(at: worktree.appending(path: "canvases"), withDestinationURL: outside)
        path = worktree.appending(path: "canvases/deck.udcanvas").path
    }

    private func worker() -> CanvasDiskWorker { CanvasDiskWorker(path: path, worktree: worktree.path) }

    private func outsideIsUntouched() throws {
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path) == ["deck.udcanvas"])
        #expect(try Data(contentsOf: outsideFile) == original)
    }

    @Test func aReadIsRefusedAndReturnsNothingFromOutside() async throws {
        guard case .unreadable = await worker().perform(.read) else {
            Issue.record("the file outside was read")
            return
        }
    }

    @Test func theOpeningReadIsRefusedToo() {
        guard case .unreadable = CanvasDiskWorker.read(path, worktree: worktree.path) else {
            Issue.record("the file outside was read")
            return
        }
    }

    @Test func aSaveWritesNothingOutside() async throws {
        let answer = await worker().perform(.save(Data("mine".utf8), expecting: [original]))
        guard case .writeFailed = answer else {
            Issue.record("expected a failed write, got \(answer)")
            return
        }
        try outsideIsUntouched()
    }

    @Test func aSaveOverWritesNothingOutside() async throws {
        let answer = await worker().perform(.save(Data("mine".utf8), expecting: nil))
        guard case .saveOverRefused = answer else {
            Issue.record("expected a refusal, got \(answer)")
            return
        }
        try outsideIsUntouched()
    }

    @Test func aBackupWritesNothingOutside() async throws {
        let answer = await worker().perform(.backup(Data("mine".utf8)))
        guard case .backupFailed = answer else {
            Issue.record("expected a failed backup, got \(answer)")
            return
        }
        try outsideIsUntouched()
    }

    @Test func aFolderLinkThatStaysInsideStillWorks() async throws {
        let inside = worktree.appending(path: "elsewhere")
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: worktree.appending(path: "linked"), withDestinationURL: inside)
        let file = worktree.appending(path: "linked/deck.udcanvas").path
        let answer = await CanvasDiskWorker(path: file, worktree: worktree.path).perform(.save(Data("mine".utf8), expecting: nil))
        #expect(answer == .written(Data("mine".utf8)))
    }
}
