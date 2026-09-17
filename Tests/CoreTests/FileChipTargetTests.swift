import Testing
import Foundation
@testable import Core

@Suite("File chip target")
struct FileChipTargetTests {
    private static let worktree = "/Users/freek/dev/code/unifieddev"

    @Test("an absolute path inside the worktree is previewed and opened relative to it")
    func insideTheWorktree() {
        let target = FileChipTarget.resolve(Self.worktree + "/Sources/UnifiedDev/App.swift", in: Self.worktree)
        #expect(target == FileChipTarget(
            path: "Sources/UnifiedDev/App.swift",
            worktree: Self.worktree,
            opens: "Sources/UnifiedDev/App.swift"
        ))
    }

    @Test("a relative path is already what both answers want")
    func alreadyRelative() {
        let target = FileChipTarget.resolve(".unifieddev/attachments/9JV/shot.png", in: Self.worktree)
        #expect(target == FileChipTarget(
            path: ".unifieddev/attachments/9JV/shot.png",
            worktree: Self.worktree,
            opens: ".unifieddev/attachments/9JV/shot.png"
        ))
    }

    @Test("a leading ./ comes off, because the review resolves neither form differently")
    func dotSlash() {
        let target = FileChipTarget.resolve("./Tools/build.sh", in: Self.worktree)
        #expect(target.path == "Tools/build.sh")
        #expect(target.opens == "Tools/build.sh")
    }

    @Test("a file outside the worktree keeps its absolute path and is previewed against nothing", arguments: [
        "/Users/freek/Desktop/shot.png",
        "/Users/freek/dev/code/other/README.md",
        "/tmp/T/CleanShot.jpg",
    ])
    func outsideTheWorktree(path: String) {
        let target = FileChipTarget.resolve(path, in: Self.worktree)
        #expect(target == FileChipTarget(path: path, worktree: "", opens: nil))
    }

    @Test("a path that climbs out of the worktree has nowhere to open")
    func climbsOut() {
        let target = FileChipTarget.resolve("../other/README.md", in: Self.worktree)
        #expect(target.opens == nil)
        #expect(target.worktree.isEmpty)
    }

    @Test("no worktree means no door")
    func noWorktree() {
        let target = FileChipTarget.resolve("Sources/UnifiedDev/App.swift", in: "")
        #expect(target == FileChipTarget(path: "Sources/UnifiedDev/App.swift", worktree: "", opens: nil))
    }

    @Test("a screenshot's name survives, spaces and all")
    func screenshot() {
        let path = Self.worktree + "/.unifieddev/attachments/A1/CleanShot 2026-08-24 at 14.46@2x.jpg"
        let target = FileChipTarget.resolve(path, in: Self.worktree)
        #expect(target.path == ".unifieddev/attachments/A1/CleanShot 2026-08-24 at 14.46@2x.jpg")
        #expect(target.opens == target.path)
    }
}
