import Testing
@testable import Core

@Suite("The environment every subprocess starts from")
struct ShellBaseEnvironmentTests {
    @Test("the login shell's PATH leads and every other variable is kept")
    func discoveredLeads() {
        let env = Shell.baseEnvironment(
            process: ["PATH": "/usr/bin:/bin", "HOME": "/Users/x"],
            discovered: ["/Users/x/.rbenv/shims", "/usr/bin"],
            guessed: ["/opt/homebrew/bin", "/usr/bin"]
        )
        #expect(env["PATH"] == "/Users/x/.rbenv/shims:/usr/bin:/bin:/opt/homebrew/bin")
        #expect(env["HOME"] == "/Users/x")
    }

    @Test("without an answer the PATH is what the app inherited, then the guesses")
    func noAnswerKeepsTheOldOrder() {
        let env = Shell.baseEnvironment(
            process: ["PATH": "/usr/bin:/bin"],
            discovered: [],
            guessed: ["/opt/homebrew/bin", "/bin"]
        )
        #expect(env["PATH"] == "/usr/bin:/bin:/opt/homebrew/bin")
    }

    @Test("an app launched with no PATH at all still gets one")
    func noInheritedPath() {
        let env = Shell.baseEnvironment(process: [:], discovered: ["/a"], guessed: ["/b"])
        #expect(env["PATH"] == "/a:/b")
    }

    @Test("adopting nothing leaves the environment alone")
    func adoptingNothingLeavesTheEnvironmentAlone() {
        let before = Shell.environment()["PATH"]
        Shell.adoptLoginShellPath([])
        #expect(Shell.environment()["PATH"] == before)
    }

    @Test("an overlay still wins over the base")
    func overlayWins() {
        #expect(Shell.environment(extra: ["PATH": "/only"])["PATH"] == "/only")
    }
}
