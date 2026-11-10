import Foundation
import Testing
@testable import Core

@Suite("What the alias probe lets out of this Mac, and what it leaves behind", .tags(.agentProtocol, .subprocess), .scratchDirectory)
struct ClaudeAliasProbeIsolationTests {
    private func fakeCLI(_ body: String) throws -> String {
        let path = TestScratch.path("bin/claude-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try ("#!/bin/sh\n" + body + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    private func realProbe(_ executable: String, inherited: [String: String] = [:]) -> ClaudeAliasProbe {
        ClaudeAliasProbe(
            executable: executable, workRoot: probeWorkRoot(),
            environment: ["PATH": "/usr/bin:/bin"].merging(inherited) { _, new in new },
            timeout: .seconds(10), exitGrace: .milliseconds(200), managed: unmanaged(),
            activity: ClaudeAccountActivity()
        )
    }

    private func resolve(
        _ probe: ClaudeAliasProbe, _ aliases: [String], account: AgentAccountHome, upTo deadline: Duration
    ) async -> ClaudeAliasAnswers? {
        let finished = AwaitedAnswer<ClaudeAliasAnswers>()
        Task { finished.set(await probe.resolve(aliases, account: account)) }
        return await finished.wait(upTo: deadline)
    }

    @Test("a CLI that ignores the request to stop is killed, and the probe still answers", .timeLimit(.minutes(1)))
    func killsACLIThatIgnoresTerminate() async {
        let launches = ProbeLaunches()
        let probe = scriptedProbe(launches, ignoresTerminate: true) { alias in [probeInitLine("claude-\(alias)-5-5")] }

        let answers = await resolve(probe, ["opus", "sonnet"], account: probeAccount(), upTo: .seconds(10))

        #expect(answers?.probed == ["opus": "claude-opus-5-5", "sonnet": "claude-sonnet-5-5"])
        #expect(launches.processes.map(\.killCount) == [1, 1])
        #expect(launches.processes.allSatisfy { !$0.isRunning })
    }

    @Test("a process that ignores SIGTERM is ended by SIGKILL instead of holding the probe", .timeLimit(.minutes(1)))
    func endsARealProcessThatIgnoresSigterm() async throws {
        let record = TestScratch.path("record")
        try FileManager.default.createDirectory(atPath: record, withIntermediateDirectories: true)
        let cli = try fakeCLI("""
        trap '' TERM
        echo $$ > "$PROBE_RECORD/pid"
        echo '{"type":"system","subtype":"init","model":"claude-opus-5-5"}'
        exec /bin/sleep 600
        """)

        let answers = await resolve(
            realProbe(cli, inherited: ["PROBE_RECORD": record]), ["opus"], account: probeAccount(), upTo: .seconds(15)
        )
        let pid = try #require(Int32(String(contentsOfFile: record + "/pid", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)))
        let stillAlive = kill(pid, 0) == 0
        if stillAlive { kill(pid, SIGKILL) }

        #expect(answers?.probed == ["opus": "claude-opus-5-5"])
        #expect(!stillAlive)
    }

    @Test("the address gets no answer and every proxied request is refused, as the CLI would see them", .timeLimit(.minutes(1)))
    func nothingTheCLISendsGetsAnAnswer() async throws {
        let record = TestScratch.path("record")
        try FileManager.default.createDirectory(atPath: record, withIntermediateDirectories: true)
        let cli = try fakeCLI("""
        /usr/bin/curl -s -o /dev/null -m 1 "$ANTHROPIC_BASE_URL/v1/messages"; echo $? > "$PROBE_RECORD/base"
        /usr/bin/curl -s -o /dev/null -m 3 https://192.0.2.1/; echo $? > "$PROBE_RECORD/https"
        /usr/bin/curl -s -o /dev/null -m 3 http://192.0.2.1/; echo $? > "$PROBE_RECORD/http"
        echo '{"type":"system","subtype":"init","model":"claude-opus-5-5"}'
        exec /bin/sleep 30
        """)
        let inherited = [
            "PROBE_RECORD": record,
            "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
            "HTTPS_PROXY": "http://proxy.example:8080",
        ]

        let answers = await resolve(realProbe(cli, inherited: inherited), ["opus"], account: probeAccount(), upTo: .seconds(30))
        func code(_ name: String) -> Int? {
            (try? String(contentsOfFile: (record as NSString).appendingPathComponent(name), encoding: .utf8))
                .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        #expect(answers?.probed == ["opus": "claude-opus-5-5"])
        #expect(code("base") == 28)
        #expect([7, 35, 52, 56].contains(code("https") ?? 28))
        #expect([7, 52, 56].contains(code("http") ?? 28))
    }

    @Test("each probe runs in a directory of its own, found empty and removed afterwards", .timeLimit(.minutes(1)))
    func runsInAFreshDirectory() async throws {
        let record = TestScratch.path("record")
        try FileManager.default.createDirectory(atPath: record, withIntermediateDirectories: true)
        let cli = try fakeCLI("""
        pwd -P >> "$PROBE_RECORD/cwd"
        ls -A | wc -l | tr -d ' ' >> "$PROBE_RECORD/entries"
        touch left-behind
        echo '{"type":"system","subtype":"init","model":"claude-opus-5-5"}'
        """)
        let probe = realProbe(cli, inherited: ["PROBE_RECORD": record])

        _ = await resolve(probe, ["opus"], account: probeAccount(), upTo: .seconds(15))
        _ = await resolve(probe, ["opus"], account: probeAccount(), upTo: .seconds(15))
        let directories = try String(contentsOfFile: record + "/cwd", encoding: .utf8).split(separator: "\n").map(String.init)
        let entries = try String(contentsOfFile: record + "/entries", encoding: .utf8).split(separator: "\n")

        #expect(directories.count == 2)
        #expect(Set(directories).count == 2)
        #expect(entries == ["0", "0"])
        #expect(!directories.contains { $0.contains(AgentScratchDirectory.folderName) })
        #expect(directories.allSatisfy { !FileManager.default.fileExists(atPath: $0) })
    }
}

@Suite("When the alias probe stays out of the way", .tags(.agentProtocol), .scratchDirectory)
struct ClaudeAliasProbeRestraintTests {
    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("a managed settings source that sets anything stops the probe before any launch", arguments: [
        "root/managed-settings.json", "root/managed-settings.d/10-proxy.json",
        "preferences/tester/com.anthropic.claudecode.plist", "preferences/com.anthropic.claudecode.plist",
        "account/remote-settings.json",
    ])
    func managedSettingsStopTheProbe(document: String) async throws {
        let account = probeAccount()
        let managed = unmanaged()
        let url = document.hasPrefix("account/")
            ? account.directory.appending(path: String(document.dropFirst("account/".count)))
            : URL(filePath: TestScratch.path("managed/\(document)"))
        let contents = url.pathExtension == "plist"
            ? #"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>apiKeyHelper</key><string>x</string></dict></plist>"#
            : #"{"env":{"ANTHROPIC_BASE_URL":"https://gateway.example"}}"#
        try write(contents, to: url)
        let launches = ProbeLaunches()

        let answers = await scriptedProbe(launches, managed: managed) { alias in [probeInitLine("claude-\(alias)-5-5")] }
            .resolve(["opus"], account: account)

        #expect(launches.launches.isEmpty)
        #expect(answers.all.isEmpty)
    }

    @Test("an empty managed document, as a personal account carries, does not stop it")
    func emptyRemoteSettingsLetTheProbeRun() async throws {
        let account = probeAccount()
        try write("{}", to: account.directory.appending(path: "remote-settings.json"))
        let launches = ProbeLaunches()

        let answers = await scriptedProbe(launches) { alias in [probeInitLine("claude-\(alias)-5-5")] }
            .resolve(["opus"], account: account)

        #expect(answers.probed == ["opus": "claude-opus-5-5"])
    }

    @Test("a managed document that cannot be read is treated as one that sets something")
    func unreadableManagedSettingsStopTheProbe() async throws {
        try write("not json", to: URL(filePath: TestScratch.path("managed/root/managed-settings.json")))
        let launches = ProbeLaunches()

        _ = await scriptedProbe(launches) { _ in [] }.resolve(["opus"], account: probeAccount())

        #expect(launches.launches.isEmpty)
    }

    @Test("an alias the account pins in its settings is answered from the pin, without a launch")
    func pinnedAliasesAreReadNotProbed() async throws {
        let account = probeAccount()
        try write(
            #"{"env":{"ANTHROPIC_DEFAULT_OPUS_MODEL":"claude-opus-4-1-20250805","ANTHROPIC_BASE_URL":"https://x"}}"#,
            to: account.directory.appending(path: "settings.json")
        )
        let launches = ProbeLaunches()

        let answers = await scriptedProbe(launches) { alias in [probeInitLine("claude-\(alias)-5-5")] }
            .resolve(["opus", "sonnet"], account: account)

        #expect(answers.pinned == ["opus": "claude-opus-4-1-20250805"])
        #expect(answers.probed == ["sonnet": "claude-sonnet-5-5"])
        #expect(launches.launches.map(probedAlias(of:)) == ["sonnet"])
    }

    @Test("no launch starts while a turn of the same account is running, and another account is not held")
    func waitsForTheAccountsTurns() async {
        let activity = ClaudeAccountActivity()
        let work = probeAccount("work")
        let client = probeAccount("client")
        let lease = await activity.beginRun(work.id)
        let launches = ProbeLaunches()
        let probe = scriptedProbe(launches, activity: activity) { alias in [probeInitLine("claude-\(alias)-5-5")] }

        let held = await probe.resolve(["opus"], account: work)
        let free = await probe.resolve(["opus"], account: client)
        lease.end()
        let afterwards = await probe.resolve(["opus"], account: work)

        #expect(held.all.isEmpty)
        #expect(free.probed == ["opus": "claude-opus-5-5"])
        #expect(afterwards.probed == ["opus": "claude-opus-5-5"])
        #expect(launches.launches.count == 2)
    }

    @Test("a turn that starts during a probe waits for the launch in flight, and the probe asks nothing more", .timeLimit(.minutes(1)))
    func aTurnWaitsForTheLaunchInFlight() async throws {
        let activity = ClaudeAccountActivity()
        let work = probeAccount()
        let launches = ProbeLaunches()
        let probe = scriptedProbe(launches, timeout: .seconds(30), activity: activity) { _ in [] }

        let answers = AwaitedAnswer<ClaudeAliasAnswers>()
        Task { answers.set(await probe.resolve(["opus", "sonnet"], account: work)) }
        while launches.launches.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        let admitted = AwaitedAnswer<Bool>()
        Task {
            let lease = await activity.beginRun(work.id)
            admitted.set(true)
            withExtendedLifetime(lease) {}
        }
        try await Task.sleep(for: .milliseconds(100))
        let admittedDuringLaunch = admitted.answer != nil
        launches.processes.first?.terminate()

        #expect(await admitted.wait(upTo: .seconds(5)) == true)
        #expect(await answers.wait(upTo: .seconds(5)) != nil)
        #expect(!admittedDuringLaunch)
        #expect(launches.launches.count == 1)
    }
}
