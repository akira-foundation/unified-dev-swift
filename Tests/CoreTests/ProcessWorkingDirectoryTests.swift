import Foundation
import Testing
@testable import Core

@Suite("ProcessWorkingDirectory")
struct ProcessWorkingDirectoryTests {
    @Test("this process's own directory is the one Foundation reports")
    func ownDirectory() throws {
        let read = try #require(ProcessWorkingDirectory.of(getpid()))
        let expected = FileManager.default.currentDirectoryPath

        #expect(read.hasPrefix("/"))
        #expect(
            URL(fileURLWithPath: read).resolvingSymlinksInPath().path
                == URL(fileURLWithPath: expected).resolvingSymlinksInPath().path
        )
    }

    @Test("no process id is nothing, rather than a directory guessed at", arguments: [pid_t(0), -1])
    func noProcess(_ pid: pid_t) {
        #expect(ProcessWorkingDirectory.of(pid) == nil)
    }
}
