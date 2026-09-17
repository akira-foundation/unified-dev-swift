import Foundation
import Testing
@testable import Core

@Suite("Folder terminal")
struct FolderTerminalTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("folder-terminal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("A folder on disk is offered")
    func offersAFolder() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(FolderTerminal.canOpen(folder: root.path))
    }

    @Test("A folder that is not on disk is not offered")
    func refusesAMissingFolder() throws {
        let root = try makeDirectory()
        let gone = root.appendingPathComponent("resources", isDirectory: true).path
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(!FolderTerminal.canOpen(folder: gone))
        #expect(FolderTerminal.target(folder: gone, taken: []) == nil)
    }

    @Test("A file is not a folder")
    func refusesAFile() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("README.md")
        try Data().write(to: file)

        #expect(!FolderTerminal.canOpen(folder: file.path))
        #expect(FolderTerminal.target(folder: file.path, taken: []) == nil)
    }

    @Test("The tab is named after the folder, not after Terminal")
    func namesAfterTheFolder() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let css = root.appendingPathComponent("resources/css", isDirectory: true)
        try FileManager.default.createDirectory(at: css, withIntermediateDirectories: true)

        let target = FolderTerminal.target(folder: css.path, taken: [])
        #expect(target?.title == "css")
        #expect(target?.directory == css.path)
    }

    @Test("A second tab for a folder of the same name is numbered")
    func numbersASecondOfTheSameName() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let css = root.appendingPathComponent("css", isDirectory: true)
        try FileManager.default.createDirectory(at: css, withIntermediateDirectories: true)

        #expect(FolderTerminal.target(folder: css.path, taken: ["css"])?.title == "css 2")
        #expect(
            FolderTerminal.target(folder: css.path, taken: ["Terminal", "css"])?.title == "css 2"
        )
    }

    @Test("A tab asking for nothing in particular is forked at the worktree root")
    func rootWhenNothingIsAsked() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(FolderTerminal.launchDirectory(requested: "", root: root.path) == root.path)
    }

    @Test("A tab asking for a folder is forked in it")
    func forksInTheFolder() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let css = root.appendingPathComponent("css", isDirectory: true)
        try FileManager.default.createDirectory(at: css, withIntermediateDirectories: true)

        #expect(FolderTerminal.launchDirectory(requested: css.path, root: root.path) == css.path)
    }

    @Test("A tab whose folder has gone falls back to the worktree root")
    func fallsBackWhenTheFolderGoes() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let css = root.appendingPathComponent("css", isDirectory: true)
        try FileManager.default.createDirectory(at: css, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: css)

        #expect(FolderTerminal.launchDirectory(requested: css.path, root: root.path) == root.path)
    }
}
