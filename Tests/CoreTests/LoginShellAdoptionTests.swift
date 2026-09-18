import Foundation
import Synchronization
import Testing
@testable import Core

@Suite(
    "Waiting for the login shell's PATH before a script runs",
    .tags(.subprocess), .scratchDirectory, .serialized, .timeLimit(.minutes(1))
)
struct LoginShellAdoptionTests {
    @Test("the probe is started once, however many times begin is called")
    func beginStartsOneProbe() async {
        let starts = Atomic<Int>(0)
        LoginShellPath.install {
            starts.add(1, ordering: .relaxed)
            return []
        }
        defer { LoginShellPath.forget() }

        LoginShellPath.begin()
        LoginShellPath.begin()
        await LoginShellPath.ready()

        #expect(starts.load(ordering: .relaxed) == 1)
    }

    @Test("ready waits for a probe already begun, and starts none of its own")
    func readyStartsNothing() async {
        let starts = Atomic<Int>(0)
        LoginShellPath.install {
            starts.add(1, ordering: .relaxed)
            return []
        }
        defer { LoginShellPath.forget() }

        await LoginShellPath.ready()

        #expect(starts.load(ordering: .relaxed) == 0)
    }

    @Test("a setup script does not start until the login shell has answered")
    func setupWaitsForTheProbe() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let answered = TestScratch.unique("probe-answered")

        LoginShellPath.install {
            try? await Task.sleep(for: .milliseconds(400))
            FileManager.default.createFile(atPath: answered, contents: nil)
            return []
        }
        defer { LoginShellPath.forget() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        if [ -f "\(answered)" ]; then echo waited; else echo raced; fi
        '''
        """)

        let store = try makeTestStore("login-shell-adoption")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Wait for the PATH")

        LoginShellPath.begin()
        let collector = LineCollector()
        let succeeded = await manager.runSetup(
            workspace: workspace, repo: registered, port: 0
        ) { collector.append($0) }

        #expect(succeeded)
        #expect(collector.joined.contains("waited"))
    }
}
