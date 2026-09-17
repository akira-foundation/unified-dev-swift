import Foundation
import Synchronization
import Testing
@testable import Core

@Suite("Worktree watcher")
struct WorktreeWatcherTests {
    @Test("a file inside a worktree is reported as that worktree")
    func attributesAFileToItsWorktree() {
        let changed = WorktreeWatcher.roots(
            of: ["/a/beta/Sources/App/View.swift"], in: WorktreeWatcher.ordered(["/a/beta"])
        )
        #expect(changed == ["/a/beta"])
    }

    @Test("the worktree's own directory is reported as itself")
    func attributesTheRootItself() {
        let changed = WorktreeWatcher.roots(of: ["/a/beta"], in: WorktreeWatcher.ordered(["/a/beta"]))
        #expect(changed == ["/a/beta"])
    }

    @Test("a worktree whose name is a prefix of another is not confused with it")
    func doesNotConfuseAPrefix() {
        let roots = WorktreeWatcher.ordered(["/a/beta", "/a/beta-two"])
        #expect(WorktreeWatcher.roots(of: ["/a/beta-two/x.txt"], in: roots) == ["/a/beta-two"])
        #expect(WorktreeWatcher.roots(of: ["/a/beta/x.txt"], in: roots) == ["/a/beta"])
    }

    @Test("a worktree nested inside another checkout is reported as itself")
    func attributesTheNestedWorktree() {
        let roots = WorktreeWatcher.ordered(["/a/repo", "/a/repo/nested"])
        #expect(WorktreeWatcher.roots(of: ["/a/repo/nested/x.txt"], in: roots) == ["/a/repo/nested"])
    }

    @Test("a path in no watched worktree is reported as nothing")
    func dropsWhatItDoesNotWatch() {
        #expect(WorktreeWatcher.roots(of: ["/somewhere/else"], in: ["/a/beta"]).isEmpty)
    }

    @Test("a storm of writes in one worktree is one answer")
    func coalescesABatch() {
        let paths = (0..<200).map { "/a/beta/file-\($0)" }
        #expect(WorktreeWatcher.roots(of: paths, in: ["/a/beta"]) == ["/a/beta"])
    }

    @Test("trailing separators do not make two roots out of one")
    func standardisesTrailingSeparators() {
        let roots = WorktreeWatcher.ordered(["/a/beta/", "/a/beta"])
        #expect(roots == ["/a/beta"])
        #expect(WorktreeWatcher.roots(of: ["/a/beta/x"], in: roots) == ["/a/beta"])
    }

    @Test("a write inside a watched directory wakes the watcher", .timeLimit(.minutes(1)))
    func reportsARealWrite() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("unifieddev-watcher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let watchedPath = root.path

        let reported = Mutex<Set<String>>([])
        let watcher = WorktreeWatcher { changed in
            reported.withLock { $0.formUnion(changed) }
        }
        defer { watcher.stop() }
        watcher.watch(roots: [watchedPath])

        try await Task.sleep(for: .milliseconds(300))
        try Data("hello".utf8).write(to: root.appendingPathComponent("file.txt"))

        var waited = Duration.zero
        while reported.withLock({ $0.isEmpty }), waited < .seconds(20) {
            try await Task.sleep(for: .milliseconds(100))
            waited += .milliseconds(100)
        }
        #expect(reported.withLock { $0 } == [watchedPath])
    }

    @Test("watching nothing tears the stream down without complaint")
    func stopsCleanly() {
        let watcher = WorktreeWatcher { _ in }
        watcher.watch(roots: ["/tmp"])
        watcher.watch(roots: [])
        watcher.stop()
    }
}
