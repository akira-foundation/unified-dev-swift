import Foundation
import Testing
@testable import Core

@Suite("Reading the login shell's PATH")
struct LoginShellPathTests {
    private func dump(_ records: [String], noise: String = "") -> Data {
        Data((noise + "\0" + records.joined(separator: "\0")).utf8)
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

    @Test("whatever the shell printed before the sentinel is discarded")
    func discardsWhateverCameBeforeTheSentinel() {
        let data = dump(["PATH=/opt/homebrew/bin"], noise: "a new release is available\n")
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/opt/homebrew/bin"])
    }

    @Test("a banner that ends without a newline still does not hide the PATH")
    func aBannerWithoutATrailingNewlineIsStillDiscarded() {
        let data = dump(["PATH=/opt/homebrew/bin"], noise: "nvm: now using node v20")
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/opt/homebrew/bin"])
    }

    @Test("a banner cannot pass itself off as the PATH")
    func aBannerCannotPassItselfOffAsThePath() {
        let data = dump(["HOME=/Users/x"], noise: "PATH=/tmp/evil:")
        #expect(LoginShellPath.directories(inEnvironmentDump: data).isEmpty)
    }

    @Test("a newline inside another value is not a record boundary")
    func aNewlineInsideAnotherValueIsNotARecordBoundary() {
        let data = dump(["HOME=/Users/x", "LS_COLORS=one\nPATH=/wrong", "PATH=/usr/bin"])
        #expect(LoginShellPath.directories(inEnvironmentDump: data) == ["/usr/bin"])
    }

    @Test("only absolute entries reach the merged PATH")
    func keepsOnlyAbsoluteEntries() {
        let merged = LoginShellPath.merge(
            discovered: ["/usr/bin", "node_modules/.bin", "", ".", "/bin"], inherited: [], guessed: []
        )
        #expect(merged == ["/usr/bin", "/bin"])
    }

    @Test("a directory named twice is kept once, where it first appears")
    func dropsDuplicateEntries() {
        let merged = LoginShellPath.merge(
            discovered: ["/usr/bin", "/bin", "/usr/bin"], inherited: [], guessed: []
        )
        #expect(merged == ["/usr/bin", "/bin"])
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
