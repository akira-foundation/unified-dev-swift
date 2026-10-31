import Foundation
import Testing
@testable import Core

@Suite("Canvas file", .tags(.security), .scratchDirectory)
struct CanvasFileTests {
    private struct Tree {
        let given: String
        let root: String
    }

    private func tree() throws -> Tree {
        let given = TestScratch.unique("canvas work tree")
        try FileManager.default.createDirectory(atPath: given + "/docs", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: given + "/.git", withIntermediateDirectories: true)
        for file in ["docs/report.html", "docs/notes.md", "docs/chart.svg", ".env", ".git/config", "docs/data.json"] {
            try "x".write(toFile: given + "/" + file, atomically: true, encoding: .utf8)
        }
        return Tree(given: given, root: URL(filePath: given).resolvingSymlinksInPath().path)
    }

    private func outsideFile(beside root: String, named name: String = "outside.html") throws -> String {
        let path = (root as NSString).deletingLastPathComponent + "/" + name
        try "secret".write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test("a relative path inside the worktree resolves")
    func relative() throws {
        let tree = try tree()
        let result = CanvasFile.resolve(path: "docs/report.html", worktree: tree.given)
        #expect(result == .file(absolute: tree.root + "/docs/report.html", relative: "docs/report.html"))
    }

    @Test("an absolute path inside the worktree resolves")
    func absolute() throws {
        let tree = try tree()
        let result = CanvasFile.resolve(path: tree.root + "/docs/notes.md", worktree: tree.given)
        #expect(result == .file(absolute: tree.root + "/docs/notes.md", relative: "docs/notes.md"))
    }

    @Test("a name with spaces, a hash, a percent and accents resolves")
    func oddName() throws {
        let tree = try tree()
        let odd = tree.root + "/docs/relatório #2 a 100%.md"
        try "x".write(toFile: odd, atomically: true, encoding: .utf8)

        let result = CanvasFile.resolve(path: "docs/relatório #2 a 100%.md", worktree: tree.given)
        guard case let .file(absolute, relative) = result else {
            Issue.record("expected a file, got \(result)")
            return
        }
        let address = try #require(DocumentPreview.address(forFile: absolute, root: tree.given))

        #expect(absolute == odd)
        #expect(relative == "docs/relatório #2 a 100%.md")
        #expect(DocumentPreview.file(for: address, root: tree.given)?.path == odd)
    }

    @Test("a climb out of the worktree is refused", arguments: ["../outside.html", "docs/../../outside.html"])
    func climbing(_ path: String) throws {
        let tree = try tree()
        _ = try outsideFile(beside: tree.root)
        guard case .refused = CanvasFile.resolve(path: path, worktree: tree.given) else {
            Issue.record("expected a refusal for \(path)")
            return
        }
    }

    @Test("an absolute path outside the worktree is refused, as a link out of the canvas would be")
    func absoluteOutside() throws {
        let tree = try tree()
        let outside = try outsideFile(beside: tree.root, named: "linked-from-canvas.md")
        guard case .refused = CanvasFile.resolve(path: outside, worktree: tree.given) else {
            Issue.record("an absolute path outside the worktree resolved")
            return
        }
    }

    @Test("a symlink pointing outside the worktree is refused")
    func symlinkOut() throws {
        let tree = try tree()
        let outside = try outsideFile(beside: tree.root, named: "linked-outside.html")
        try FileManager.default.createSymbolicLink(atPath: tree.root + "/docs/link.html", withDestinationPath: outside)
        guard case .refused = CanvasFile.resolve(path: "docs/link.html", worktree: tree.given) else {
            Issue.record("expected a refusal")
            return
        }
    }

    @Test("withheld names are refused, whatever their case", arguments: [".env", ".git/config", ".ENV", ".Git/config"])
    func withheld(_ path: String) throws {
        let tree = try tree()
        guard case .refused = CanvasFile.resolve(path: path, worktree: tree.given) else {
            Issue.record("expected a refusal for \(path)")
            return
        }
    }

    @Test("a path carrying a NUL is refused")
    func nul() throws {
        let tree = try tree()
        guard case .refused = CanvasFile.resolve(path: "docs/report.html\0.md", worktree: tree.given) else {
            Issue.record("a path with a NUL resolved")
            return
        }
    }

    @Test("a symlink inside the worktree pointing at .env is refused")
    func symlinkToEnv() throws {
        let tree = try tree()
        try FileManager.default.createSymbolicLink(atPath: tree.root + "/docs/env.html", withDestinationPath: tree.root + "/.env")
        guard case .refused = CanvasFile.resolve(path: "docs/env.html", worktree: tree.given) else {
            Issue.record("a link to .env resolved")
            return
        }
    }

    @Test("an empty worktree contains nothing, not even an absolute path")
    func emptyWorktree() throws {
        let tree = try tree()
        guard case .refused = CanvasFile.resolve(path: tree.root + "/docs/report.html", worktree: "") else {
            Issue.record("an empty worktree accepted an absolute path")
            return
        }
    }

    @Test("what the canvas draws is decided by containment and type, not by the file being there yet")
    func showable() throws {
        let tree = try tree()
        #expect(
            CanvasFile.showable(path: "docs/gone.html", worktree: tree.given)
                == .file(absolute: tree.root + "/docs/gone.html", relative: "docs/gone.html")
        )
        for path in ["../outside.html", ".env", "docs/data.json", "docs/gone.json"] {
            guard case .refused = CanvasFile.showable(path: path, worktree: tree.given) else {
                Issue.record("expected the canvas to refuse \(path)")
                return
            }
        }
    }

    @Test("a directory, a missing file and an unsupported type are refused, each in its own words")
    func otherRefusals() throws {
        let tree = try tree()
        var sentences: [String] = []
        for path in ["docs", "docs/nope.html", "docs/data.json"] {
            guard case let .refused(sentence) = CanvasFile.resolve(path: path, worktree: tree.given) else {
                Issue.record("expected a refusal for \(path)")
                return
            }
            sentences.append(sentence)
        }
        #expect(sentences.allSatisfy { !$0.isEmpty })
        #expect(Set(sentences).count == 3)
    }

    @Test("every refusal reason has its own sentence")
    func distinctReasons() throws {
        let tree = try tree()
        _ = try outsideFile(beside: tree.root)
        var sentences: Set<String> = []
        for path in ["../outside.html", ".env", "docs", "docs/nope.html", "docs/data.json"] {
            if case let .refused(sentence) = CanvasFile.resolve(path: path, worktree: tree.given) {
                sentences.insert(sentence)
            }
        }
        #expect(sentences.count == 5)
    }

    @Test("accepts is case insensitive and knows every format")
    func accepts() {
        for path in ["A.HTML", "b.Md", "c.svg", "d.webp"] {
            #expect(CanvasFile.accepts(path: path))
        }
        for path in ["e.json", "f"] {
            #expect(!CanvasFile.accepts(path: path))
        }
    }
}
