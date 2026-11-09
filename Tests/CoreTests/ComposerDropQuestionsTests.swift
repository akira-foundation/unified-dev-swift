import Foundation
import Synchronization
import Testing
@testable import Core

@Suite("Composer drop questions")
struct ComposerDropQuestionsTests {
    @Test("Only file sources are asked about, and never more than the ceiling")
    func asksAtMostTheCeiling() {
        let asked = Mutex(0)
        let paths: [String?] = [nil] + (0..<(ComposerDropQuestions.maximumAsked + 5)).map { "/tmp/\($0)" }

        let items = ComposerDropQuestions.items(for: paths) { _ in
            asked.withLock { $0 += 1 }
            return true
        }

        #expect(asked.withLock { $0 } == ComposerDropQuestions.maximumAsked)
        #expect(items.first == .attachment)
        #expect(items.dropFirst().prefix(ComposerDropQuestions.maximumAsked).allSatisfy { $0 != .attachment })
        #expect(items.suffix(5).allSatisfy { $0 == .unasked })
    }

    @Test("A root that is a symlink is known by both names, and no root is asked for nothing")
    func rootsResolve() {
        #expect(ComposerDropQuestions.roots(under: "/a", resolve: { _ in "/b" }) == ["/a", "/b"])
        #expect(ComposerDropQuestions.roots(under: "/a", resolve: { $0 }) == ["/a"])
        #expect(ComposerDropQuestions.roots(under: "", resolve: { _ in "/b" }) == [])
    }

    @Test("A drop with no file on it needs no question, and nothing asked attaches everything")
    func nothingToAsk() {
        #expect(!ComposerDropQuestions.needsAsking([nil, nil]))
        #expect(ComposerDropQuestions.needsAsking([nil, "/tmp/a"]))
        #expect(ComposerDropQuestions.nothingAsked(count: 2) == ComposerDropAnswers(items: [.attachment, .attachment], roots: []))
    }

    @Test("The disk's answers are the real folder and symlink ones, and the root reaches the answer", .scratchDirectory)
    func answersFromTheDisk() async throws {
        let base = URL(filePath: TestScratch.unique("drop"), directoryHint: .isDirectory)
        let folder = base.appending(path: "folder", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = base.appending(path: "file.txt")
        try Data("x".utf8).write(to: file)
        let link = base.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        #expect(ComposerDropQuestions.isFolderOnDisk(folder.path))
        #expect(!ComposerDropQuestions.isFolderOnDisk(file.path))
        #expect(!ComposerDropQuestions.isFolderOnDisk(base.appending(path: "nothing").path))
        #expect(ComposerDropQuestions.resolvingSymlinks(link.path).hasSuffix("/folder"))

        let answers = await ComposerDropQuestions.answer(paths: [folder.path], under: link.path)
        #expect(answers.items == [.folder(folder.path)])
        #expect(answers.roots.count == 2)
        #expect(answers.roots.first == link.path)
    }

    @MainActor
    @Test("A drop's question is never asked on the main thread")
    func neverAskedOnTheMainThread() async {
        let askedOnMain = Mutex(false)

        let answers = await ComposerDropQuestions.answer(
            paths: ["/mnt/dead/folder"],
            under: "",
            isFolder: { _ in
                askedOnMain.withLock { $0 = Thread.isMainThread }
                return true
            }
        )

        #expect(!askedOnMain.withLock { $0 })
        #expect(answers.items == [.folder("/mnt/dead/folder")])
    }
}
