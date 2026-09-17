import Foundation
import Testing
@testable import Core

@Suite("Asking the login shell for its PATH", .tags(.subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct LoginShellProbeTests {
    static let hasNoControllingTerminal: Bool = {
        let descriptor = open("/dev/tty", O_RDWR | O_NOCTTY)
        guard descriptor >= 0 else { return true }
        close(descriptor)
        return false
    }()

    static let probeIsTurnedOff = ProcessInfo.processInfo.environment["UD_LOGIN_SHELL_PATH"] == "0"

    private func directory(_ name: String) throws -> String {
        let path = TestScratch.unique(name)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func fakeShell(_ body: String, in directory: String) throws -> String {
        let path = (directory as NSString).appendingPathComponent("shell")
        try ("#!/bin/sh\n" + body).write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    private func pid(at path: String) throws -> pid_t {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return try #require(pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    @Test("a shell that answers is asked with separate flags and read")
    func readsTheAnswer() async throws {
        let folder = try directory("answering-shell")
        let shell = try fakeShell(
            """
            [ "$1" = -i ] && [ "$2" = -l ] && [ "$3" = -c ] && [ "$4" = "/usr/bin/env -0" ] || exit 3
            printf 'welcome back\\n'
            printf 'HOME=/x\\000PATH=/fake/bin:/usr/bin\\000'
            """,
            in: folder
        )

        let found = await LoginShellPath.discover(shell: shell, environment: [:])

        #expect(found == ["/fake/bin", "/usr/bin"])
    }

    @Test("a shell that exits non-zero answers nothing, whatever it printed")
    func failureAnswersNothing() async throws {
        let folder = try directory("failing-shell")
        let shell = try fakeShell("printf 'PATH=/fake/bin\\000'\nexit 1\n", in: folder)

        #expect(await LoginShellPath.discover(shell: shell, environment: [:]).isEmpty)
    }

    @Test("a shell that is not there answers nothing")
    func missingShellAnswersNothing() async {
        #expect(await LoginShellPath.discover(shell: "/nonexistent/shell", environment: [:]).isEmpty)
    }

    @Test("UD_LOGIN_SHELL_PATH=0 starts no process at all")
    func switchedOffStartsNothing() async throws {
        let folder = try directory("switched-off")
        let marker = (folder as NSString).appendingPathComponent("ran")
        let shell = try fakeShell("touch '\(marker)'\nprintf 'PATH=/fake/bin\\000'\n", in: folder)

        let found = await LoginShellPath.discover(shell: shell, environment: ["UD_LOGIN_SHELL_PATH": "0"])

        #expect(found.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: marker))
    }

    @Test("a startup file that reads gets end of file rather than a wait")
    func readingStdinDoesNotWait() async throws {
        let folder = try directory("reading-shell")
        let shell = try fakeShell("read answer\nprintf 'PATH=/after/read\\000'\n", in: folder)
        let started = ContinuousClock.now

        let found = await LoginShellPath.discover(shell: shell, environment: [:], timeout: .seconds(5))

        #expect(found == ["/after/read"])
        #expect(started.duration(to: .now) < .seconds(4))
    }

    @Test("a startup file that never returns is stopped at the timeout, children and all")
    func hangingShellIsKilledWithItsGroup() async throws {
        let folder = try directory("hanging-shell")
        let shell = try fakeShell(
            """
            sleep 30 &
            echo $! > "$(dirname "$0")/child.pid"
            echo $$ > "$(dirname "$0")/shell.pid"
            sleep 30
            """,
            in: folder
        )
        let started = ContinuousClock.now

        let found = await LoginShellPath.discover(shell: shell, environment: [:], timeout: .seconds(1))

        #expect(found.isEmpty)
        #expect(started.duration(to: .now) < .seconds(4))
        let child = try pid(at: (folder as NSString).appendingPathComponent("child.pid"))
        let parent = try pid(at: (folder as NSString).appendingPathComponent("shell.pid"))
        await waitUntil("the shell and the child it started have both gone") {
            kill(parent, 0) != 0 && kill(child, 0) != 0
        }
    }

    @Test(
        "a real zsh whose .zshrc never returns is stopped at the timeout",
        .enabled(if: LoginShellProbeTests.hasNoControllingTerminal, "zsh -i contends for a controlling terminal")
    )
    func slowZshrcIsStopped() async throws {
        let home = try directory("slow-zdotdir")
        try "sleep 30\n".write(
            toFile: (home as NSString).appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8
        )
        let started = ContinuousClock.now

        let found = await LoginShellPath.discover(
            shell: "/bin/zsh", environment: [:], overlay: ["ZDOTDIR": home], timeout: .seconds(2)
        )

        #expect(found.isEmpty)
        #expect(started.duration(to: .now) < .seconds(5))
    }

    @Test(
        "a real zsh reads PATH as its .zshrc left it, even when the .zshrc asks a question",
        .enabled(if: LoginShellProbeTests.hasNoControllingTerminal, "zsh -i contends for a controlling terminal")
    )
    func interactiveZshrcAnswers() async throws {
        let home = try directory("asking-zdotdir")
        try "read -r reply\nexport PATH=/from/zshrc:$PATH\n".write(
            toFile: (home as NSString).appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8
        )

        let found = await LoginShellPath.discover(
            shell: "/bin/zsh", environment: [:], overlay: ["ZDOTDIR": home], timeout: .seconds(5)
        )

        #expect(found.first == "/from/zshrc")
    }

    @Test(
        "with the probe switched off, begin and ready return and change nothing",
        .enabled(if: LoginShellProbeTests.probeIsTurnedOff, "Tools/test-core.sh switches the probe off")
    )
    func readyWithTheProbeOff() async {
        let before = Shell.environment()["PATH"]

        LoginShellPath.begin()
        LoginShellPath.begin()
        await LoginShellPath.ready()
        await LoginShellPath.ready()

        #expect(Shell.environment()["PATH"] == before)
    }
}
