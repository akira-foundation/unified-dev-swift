import Foundation
import Testing
@testable import Core

@Suite("Worktree watcher descriptors", .serialized)
struct WorktreeWatcherDescriptorTests {
    private static func openDescriptors() -> Int {
        (0..<4096).filter { fcntl(Int32($0), F_GETFD) != -1 }.count
    }

    private static func standardInput() -> ino_t? {
        var status = stat()
        return fstat(0, &status) == 0 ? status.st_ino : nil
    }

    private static func roots(_ count: Int) throws -> (base: URL, paths: [String]) {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "ud-watch-descriptors-\(UUID().uuidString)/a/b/c/d", directoryHint: .isDirectory)
        let paths = try (0..<count).map { index in
            let root = base.appending(path: "root-\(index)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root.path
        }
        return (base, paths)
    }

    @Test("streams are created without watching the roots themselves")
    func flagsLeaveTheRootsUnwatched() {
        for fileEvents in [true, false] {
            let flags = WorktreeWatcher.creationFlags(fileEvents: fileEvents)
            #expect(flags & FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot) == 0)
            #expect((flags & FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents) != 0) == fileEvents)
        }
    }

    @Test("watching many roots holds no descriptor per root")
    func watchingHoldsNoDescriptorPerRoot() throws {
        let made = try Self.roots(30)
        defer { try? FileManager.default.removeItem(at: made.base.deletingLastPathComponent().deletingLastPathComponent()) }
        let watcher = WorktreeWatcher(onFilesChanged: { _ in }, onChange: { _ in })
        defer { watcher.stop() }

        let before = Self.openDescriptors()
        watcher.watch(roots: made.paths)
        let watching = Self.openDescriptors()

        #expect(watching - before < made.paths.count)
    }

    @Test("rebuilding the streams for changing roots neither leaks descriptors nor touches standard input")
    func rebuildsDoNotLeak() throws {
        let made = try Self.roots(12)
        defer { try? FileManager.default.removeItem(at: made.base.deletingLastPathComponent().deletingLastPathComponent()) }
        let watcher = WorktreeWatcher(onFilesChanged: { _ in }, onChange: { _ in })
        let input = Self.standardInput()

        watcher.watch(roots: made.paths)
        let settled = Self.openDescriptors()
        for round in 0..<60 {
            watcher.watch(roots: Array(made.paths.dropFirst(round % made.paths.count)))
        }
        watcher.watch(roots: made.paths)
        let after = Self.openDescriptors()
        watcher.stop()

        #expect(after - settled < made.paths.count)
        #expect(Self.standardInput() == input)
    }
}
