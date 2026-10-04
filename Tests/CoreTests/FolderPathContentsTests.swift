import Foundation
import Testing
@testable import Core

@Suite("Whether a folder is free to write into")
struct FolderPathContentsTests {
    private func folder(_ prefix: String = "unifieddev-folder") throws -> String {
        let path = TestScratch.unique(prefix)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func write(_ name: String, into folder: String) throws {
        try "x\n".write(
            toFile: (folder as NSString).appendingPathComponent(name),
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("a path with nothing at it is free, because a clone may create it")
    func nothingThereIsFree() {
        #expect(FolderPath.isFree(TestScratch.unique("unifieddev-absent")))
    }

    @Test("an empty folder is free")
    func emptyFolderIsFree() throws {
        #expect(FolderPath.isFree(try folder()))
    }

    @Test("a folder holding only a .DS_Store counts as empty, which Finder leaves everywhere")
    func metadataOnlyIsFree() throws {
        let path = try folder()
        try write(".DS_Store", into: path)

        #expect(FolderPath.isFree(path))
        #expect(FolderPath.isEmptyDirectory(path))
    }

    @Test("a folder with a file in it is not free")
    func occupiedFolderIsNotFree() throws {
        let path = try folder()
        try write("notes.txt", into: path)

        #expect(!FolderPath.isFree(path))
        #expect(!FolderPath.isEmptyDirectory(path))
    }

    @Test("a file where a folder was expected is not free, so a clone is refused rather than failing")
    func aFileIsNotFree() throws {
        let path = TestScratch.unique("unifieddev-file")
        try "x\n".write(toFile: path, atomically: true, encoding: .utf8)

        #expect(!FolderPath.isFree(path))
    }

    @Test("a dangling symlink is not free, so nothing unlinks what the owner put there")
    func aDanglingSymlinkIsNotFree() throws {
        let link = TestScratch.unique("unifieddev-link")
        try FileManager.default.createSymbolicLink(
            atPath: link, withDestinationPath: TestScratch.unique("unifieddev-nowhere")
        )

        #expect(FolderPath.exists(link))
        #expect(!FolderPath.isFree(link))
    }

    @Test("a missing path does not exist, and an empty folder is not the same question as free")
    func existenceIsItsOwnQuestion() throws {
        let absent = TestScratch.unique("unifieddev-absent")

        #expect(!FolderPath.exists(absent))
        #expect(!FolderPath.isEmptyDirectory(absent))
        #expect(FolderPath.isFree(absent))
    }
}
