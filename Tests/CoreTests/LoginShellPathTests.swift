import Foundation
import Testing
@testable import Core

@Suite("Reading the login shell's PATH")
struct LoginShellPathTests {
    private func dump(_ records: [String], noise: String = "") -> Data {
        Data((noise + records.joined(separator: "\0")).utf8)
    }

    @Test("the PATH record is read out of the dump")
    func readsThePathRecord() {
        let data = dump(["HOME=/Users/x", "PATH=/opt/homebrew/bin:/usr/bin", "SHELL=/bin/zsh"])
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/opt/homebrew/bin", "/usr/bin"])
    }

    @Test("no PATH record answers nothing")
    func answersNothingWhenThereIsNoPath() {
        #expect(LoginShellPath.directories(inEnvironmentDump: dump(["HOME=/Users/x"])).isEmpty)
        #expect(LoginShellPath.directories(inEnvironmentDump: Data()).isEmpty)
    }

    @Test("a banner glued to the first record does not hide the PATH")
    func survivesABannerGluedToTheFirstRecord() {
        let data = dump(["PATH=/opt/homebrew/bin"], noise: "a new release is available\n")
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/opt/homebrew/bin"])
    }

    @Test("a newline inside another value is not a record boundary")
    func aNewlineInsideAnotherValueIsNotARecordBoundary() {
        let data = dump(["HOME=/Users/x", "LS_COLORS=one\nPATH=/wrong", "PATH=/usr/bin"])
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/usr/bin"])
    }

    @Test("only absolute entries survive")
    func keepsOnlyAbsoluteEntries() {
        let data = dump(["PATH=/usr/bin:node_modules/.bin::.:/bin"])
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/usr/bin", "/bin"])
    }

    @Test("a directory named twice is kept once, where it first appears")
    func dropsDuplicateEntries() {
        let data = dump(["PATH=/usr/bin:/bin:/usr/bin"])
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/usr/bin", "/bin"])
    }

    @Test("the login shell leads, then what the app inherited, then the guesses, each once")
    func mergePutsTheLoginShellFirstAndDedupes() {
        let merged = LoginShellPath.merge(
            discovered: ["/Users/x/.rbenv/shims", "/opt/homebrew/bin"],
            inherited: ["/usr/bin", "/bin"],
            guessed: ["/opt/homebrew/bin", "/usr/bin", "/sbin"]
        )
        #expect(merged == ["/Users/x/.rbenv/shims", "/opt/homebrew/bin", "/usr/bin", "/bin", "/sbin"])
    }

    @Test("no answer merges to what Unified Dev already had")
    func mergeWithoutAnAnswerIsWhatTheAppAlreadyHad() {
        let merged = LoginShellPath.merge(
            discovered: [], inherited: ["/usr/bin", ""], guessed: ["/opt/homebrew/bin", "/usr/bin"]
        )
        #expect(merged == ["/usr/bin", "/opt/homebrew/bin"])
    }
}
