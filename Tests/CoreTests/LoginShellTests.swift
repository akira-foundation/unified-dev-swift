import Testing
import Foundation
@testable import Core

@Suite("Which shell a terminal starts")
struct LoginShellTests {
    private func path(_ shell: String?, executable: Set<String> = ["/bin/zsh", "/opt/homebrew/bin/fish"]) -> String {
        LoginShell.path(
            environment: shell.map { ["SHELL": $0] } ?? [:],
            isExecutable: executable.contains
        )
    }

    @Test("the user's own shell is used when it is really there")
    func theUsersShellWins() {
        #expect(path("/opt/homebrew/bin/fish") == "/opt/homebrew/bin/fish")
    }

    @Test("a shell that is not on disk falls back")
    func aMissingShellFallsBack() {
        #expect(path("/opt/homebrew/bin/nushell") == LoginShell.fallback)
        #expect(path(nil) == LoginShell.fallback)
    }

    @Test("an empty SHELL is not treated as a shell")
    func anEmptyShellIsNotAPath() {
        #expect(path("") == LoginShell.fallback)
    }

    @Test("argv zero is the shell's name with a dash in front")
    func argumentZeroCarriesTheDash() {
        #expect(LoginShell.argumentZero(for: "/bin/zsh") == "-zsh")
        #expect(LoginShell.argumentZero(for: "/opt/homebrew/bin/fish") == "-fish")
    }

    @Test("a rejected shell does not lend its name to the one that runs")
    func theNameFollowsTheShellThatRuns() {
        let resolved = path("/opt/homebrew/bin/nushell")
        #expect(resolved == LoginShell.fallback)
        #expect(LoginShell.argumentZero(for: resolved) == "-zsh")
        #expect(LoginShell.argumentZero(for: resolved) != "-nushell")
    }
}
